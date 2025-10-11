// lib/pages/materiais_da_turma_page.dart
// CÓDIGO FINAL COM A CORREÇÃO DE COMPILAÇÃO

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

import 'material_details.dart';

class MateriaisDaTurmaPage extends StatefulWidget {
  final String turmaId;
  final String nomeTurma;

  const MateriaisDaTurmaPage({
    super.key,
    required this.turmaId,
    required this.nomeTurma,
  });

  @override
  State<MateriaisDaTurmaPage> createState() => _MateriaisDaTurmaPageState();
}

class _MateriaisDaTurmaPageState extends State<MateriaisDaTurmaPage> {
  // Variáveis para guardar dados do usuário
  bool _isLoadingUser = true;
  String? _userRole;
  String? _studentRa;
  String? _uid;

  final _searchCtrl = TextEditingController();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _materialsStream;

  static const int kMaxInlineBytes = 700 * 1024; // ~700KB
  bool _isSaving = false;
  String? _savingStatus;

  @override
  void initState() {
    super.initState();
    _loadUserAndSetupStream();
  }

  Future<void> _loadUserAndSetupStream() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingUser = false);
      return;
    }
    _uid = user.uid;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!mounted) return;

    final data = userDoc.data();
    _userRole = data?['role']?.toString();
    _studentRa = data?['ra']?.toString();

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('materials');

    if (_userRole == 'professor') {
      query = query
          .where('classIds', arrayContains: widget.turmaId)
          .where('ownerUid', isEqualTo: _uid);
    } else if (_userRole == 'aluno' && _studentRa != null && _studentRa!.isNotEmpty) {
      query = query.where('allowedRAs', arrayContains: _studentRa);
    } else {
      query = query.where('__error__', isEqualTo: true);
    }

    _materialsStream = query.orderBy('createdAt', descending: true).snapshots();
    setState(() => _isLoadingUser = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // *** CORREÇÃO: Função movida para o escopo da classe ***
  String _fmtBytes(int b) {
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '$b B';
  }

  // ============================================================================
  // --- LÓGICA PARA ADICIONAR MATERIAL ---
  // ============================================================================

  Future<void> _showAddMaterialDialog() async {
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final linkUrlCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            void setSavingState({bool isSaving = false, String? status}) {
              setDialogState(() {
                _isSaving = isSaving;
                _savingStatus = status;
              });
            }

            Future<List<String>> _collectRAsFromCurrentClass() async {
              final ras = <String>{};
              final qs = await FirebaseFirestore.instance
                  .collection('classes')
                  .doc(widget.turmaId)
                  .collection('students')
                  .get();
              for (final s in qs.docs) {
                ras.add(s.id); // doc.id = RA
              }
              return ras.toList()..sort();
            }

            Future<void> _onSaveLink() async {
              final title = titleCtrl.text.trim();
              final subject = subjectCtrl.text.trim();
              final url = linkUrlCtrl.text.trim();

              if (url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) {
                _showSnackBar('Informe uma URL válida (http/https).', isError: true);
                return;
              }

              setSavingState(isSaving: true, status: 'Coletando RAs dos alunos...');
              final allowedRAs = await _collectRAsFromCurrentClass();

              setSavingState(status: 'Salvando link...');
              try {
                await FirebaseFirestore.instance.collection('materials').add({
                  'type': 'link',
                  'title': title.isEmpty ? url : title,
                  'subject': subject,
                  'url': url,
                  'fileName': null, 'contentType': null, 'size': null,
                  'classIds': [widget.turmaId],
                  'classNames': [widget.nomeTurma],
                  'allowedRAs': allowedRAs,
                  'ownerUid': _uid,
                  'ownerEmail': FirebaseAuth.instance.currentUser?.email ?? '',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(dialogContext);
                _showSnackBar('Link salvo com sucesso!');
              } catch (e) {
                _showSnackBar('Erro ao salvar link: $e', isError: true);
              } finally {
                setSavingState();
              }
            }
            
            Future<void> _onPickAndSaveFile() async {
              setSavingState(isSaving: true, status: 'Selecionando arquivo...');
              final result = await FilePicker.platform.pickFiles(withData: true);
              
              if (result == null || result.files.isEmpty) {
                setSavingState();
                return;
              }

              final file = result.files.single;
              if (file.bytes == null) {
                _showSnackBar('Não foi possível ler o arquivo.', isError: true);
                setSavingState();
                return;
              }
              if (file.size > kMaxInlineBytes) {
                _showSnackBar('Arquivo muito grande (máx: ${_fmtBytes(kMaxInlineBytes)}).', isError: true);
                setSavingState();
                return;
              }
              
              setSavingState(status: 'Coletando RAs dos alunos...');
              final allowedRAs = await _collectRAsFromCurrentClass();
              
              setSavingState(status: 'Salvando arquivo...');
              try {
                final b64 = base64Encode(file.bytes!);
                await FirebaseFirestore.instance.collection('materials').add({
                  'type': 'inline',
                  'title': titleCtrl.text.trim().isEmpty ? file.name : titleCtrl.text.trim(),
                  'subject': subjectCtrl.text.trim(),
                  'fileName': file.name,
                  'contentType': lookupMimeType(file.name) ?? 'application/octet-stream',
                  'size': file.size,
                  'data': b64,
                  'classIds': [widget.turmaId],
                  'classNames': [widget.nomeTurma],
                  'allowedRAs': allowedRAs,
                  'ownerUid': _uid,
                  'ownerEmail': FirebaseAuth.instance.currentUser?.email ?? '',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(dialogContext);
                _showSnackBar('Arquivo salvo com sucesso!');
              } catch (e) {
                _showSnackBar('Erro ao salvar arquivo: $e', isError: true);
              } finally {
                setSavingState();
              }
            }

            return AlertDialog(
              title: Text('Novo Material para "${widget.nomeTurma}"'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Título (opcional)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subjectCtrl,
                        decoration: const InputDecoration(labelText: 'Disciplina (opcional)', border: OutlineInputBorder()),
                      ),
                      const Divider(height: 24),
                      TextField(
                        controller: linkUrlCtrl,
                        decoration: const InputDecoration(labelText: 'URL do Link', border: OutlineInputBorder(), hintText: 'https://...'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _onSaveLink,
                        icon: const Icon(Icons.add_link),
                        label: const Text('Salvar Link'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _onPickAndSaveFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text('Anexar Arquivo (máx. ${_fmtBytes(kMaxInlineBytes)})'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                      ),
                      if (_isSaving && _savingStatus != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_savingStatus!)),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: _userRole == 'professor'
          ? FloatingActionButton.extended(
              onPressed: _showAddMaterialDialog,
              icon: const Icon(Icons.add),
              label: const Text('Novo Material'),
            )
          : null,
      appBar: AppBar(
        title: Text(
          "Materiais de ${widget.nomeTurma}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _BackButton(onTap: () => Navigator.maybePop(context)),
        leadingWidth: 136,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Bg(),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec('Buscar por título...', icon: Icons.search),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              Expanded(
                child: _isLoadingUser
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _materialsStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snap.hasError) {
                            return _ErrorMessage(error: snap.error.toString());
                          }
                          
                          final allDocs = snap.data?.docs ?? [];
                          final term = _searchCtrl.text.trim().toLowerCase();

                          final filteredDocs = allDocs.where((doc) {
                            final data = doc.data();
                            if (_userRole == 'aluno') {
                              final classIds = List<String>.from(data['classIds'] ?? []);
                              if (!classIds.contains(widget.turmaId)) {
                                return false;
                              }
                            }
                            final title = data['title']?.toString().toLowerCase() ?? '';
                            return term.isEmpty || title.contains(term);
                          }).toList();
                          
                          if (filteredDocs.isEmpty) {
                            return const Center(child: Text('Nenhum material encontrado para esta turma.', style: TextStyle(color: Colors.white70)));
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                            itemCount: filteredDocs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final d = filteredDocs[i];
                              final data = d.data();
                              final type = (data['type'] ?? '').toString();
                              final title = (data['title'] ?? 'Sem título').toString();
                              final subject = (data['subject'] ?? '').toString();
                              IconData icon = type == 'link' ? Icons.link : Icons.insert_drive_file;
                              String subtitle = subject;
                              if (type == 'inline' && subtitle.isEmpty) {
                                final name = (data['fileName'] ?? '').toString();
                                final size = (data['size'] ?? 0) as int;
                                subtitle = '$name · ${_fmtBytes(size)}';
                              }
                              return _Glass(
                                radius: 16,
                                child: ListTile(
                                  leading: Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: const LinearGradient(colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)]),
                                    ),
                                    child: Icon(icon, color: Colors.white),
                                  ),
                                  title: Text(title, style: const TextStyle(color: Colors.white)),
                                  subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.white70)) : null,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => MaterialDetailsPage(ref: d.reference)),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
      filled: true,
      fillColor: Colors.white.withOpacity(.06),
      hintStyle: const TextStyle(color: Colors.white60),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white54)),
    );
  }
}

// ----- Widgets de UI -----

class _ErrorMessage extends StatelessWidget {
  final String error;
  const _ErrorMessage({required this.error});

  @override
  Widget build(BuildContext context) {
    final url = RegExp(r'https?:\/\/[^\s\)]+').firstMatch(error)?.group(0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Erro ao carregar materiais:', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            if (url != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse(url)),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir link para criar índice'),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class _Bg extends StatelessWidget {
  const _Bg();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(image: AssetImage('assets/images/poliedro.png'), fit: BoxFit.cover),
        gradient: LinearGradient(
          colors: [const Color(0xFF0B091B).withOpacity(.88), const Color(0xFF0B091B).withOpacity(.88)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const _Glass({required this.child, this.padding, this.radius = 16});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF121022).withOpacity(.10),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(.10)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 16))],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
      label: const Text('Voltar'),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(.12),
        elevation: 0,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}