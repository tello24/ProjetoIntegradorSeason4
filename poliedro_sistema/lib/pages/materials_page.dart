import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

// IO por padrão; no web usa Blob/anchor
import '../utils/open_inline_io.dart'
  if (dart.library.html) '../utils/open_inline_web.dart';

// Tela de detalhes do material
import 'material_details.dart';

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});
  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  // --------- estado de sessão/role ---------
  late final String _uid;
  late final String _email;
  bool _loadedUser = false;
  bool _isProfessor = false;
  String? _studentRa;

  // --------- formulário (criação) ---------
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _linkUrl = TextEditingController();

  // --------- busca e filtro ---------
  final _searchCtrl = TextEditingController();
  String? _selectedSubject;

  // turmas selecionadas para NOVOS materiais
  final List<String> _selectedClassIds = [];
  final List<String> _selectedClassNames = [];

  // stream após configurar papel/RA
  Stream<QuerySnapshot<Map<String, dynamic>>>? _materialsStream;

  static const int kMaxInlineBytes = 700 * 1024; // ~700KB
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      });
      return;
    }
    _uid = u.uid;
    _email = u.email ?? '';

    // Carrega role/RA e define a stream
    FirebaseFirestore.instance.collection('users').doc(_uid).get().then((d) {
      final role = (d.data()?['role'] ?? '').toString();
      _isProfessor = role == 'professor';
      _studentRa = (d.data()?['ra'] ?? '').toString().isEmpty
          ? null
          : (d.data()?['ra'] ?? '').toString();

      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('materials');

      if (_isProfessor) {
        // professor: vê apenas os próprios
        q = q.where('ownerUid', isEqualTo: _uid);
      } else {
        // aluno: vê apenas os que têm seu RA autorizado
        q = q.where('allowedRAs', arrayContains: _studentRa);
      }

      // Dica: orderBy(createdAt) com where geralmente pede índice.
      _materialsStream = q.orderBy('createdAt', descending: true).snapshots();

      _loadedUser = true;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _linkUrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  //                           SELEÇÃO / CRIAÇÃO DE TURMAS
  // ============================================================================

  Future<void> _showNewClassDialog() async {
    final ctrl = TextEditingController();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nova turma'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome da turma (ex.: T2SUB01)',
            ),
            onSubmitted: (_) async {
              if (saving) return;
              setDlg(() => saving = true);
              await _createClass(ctrl.text);
              setDlg(() => saving = false);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      setDlg(() => saving = true);
                      await _createClass(ctrl.text);
                      setDlg(() => saving = false);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createClass(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      _snack('Informe um nome para a turma.');
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('classes').add({
        'name': name,
        'ownerUid': _uid,                 // ✅ regras exigem isto
        'ownerEmail': _email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _snack('Turma "$name" criada!');
    } on FirebaseException catch (e) {
      _snack('Falha ao criar turma: ${e.code} — ${e.message}');
    } catch (e) {
      _snack('Erro ao criar turma: $e');
    }
  }

  // Selecionar turmas para NOVOS materiais
  Future<void> _pickClasses() async {
    if (!_isProfessor) return;

    var classesSnap = await FirebaseFirestore.instance
        .collection('classes')
        .where('ownerUid', isEqualTo: _uid)
        .orderBy('name')
        .get();

    var all = classesSnap.docs
        .map((d) => (id: d.id, name: (d['name'] ?? '').toString()))
        .toList();

    final pre = Set<String>.from(_selectedClassIds);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Selecionar turmas'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await _showNewClassDialog();
                      classesSnap = await FirebaseFirestore.instance
                          .collection('classes')
                          .where('ownerUid', isEqualTo: _uid)
                          .orderBy('name')
                          .get();
                      setDlg(() {
                        all = classesSnap.docs
                            .map((d) => (id: d.id, name: (d['name'] ?? '').toString()))
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nova turma'),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in all)
                        CheckboxListTile(
                          value: pre.contains(c.id),
                          title: Text(c.name.isEmpty ? c.id : c.name),
                          onChanged: (v) => setDlg(() {
                            if (v == true) pre.add(c.id);
                            else pre.remove(c.id);
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Usar selecionadas'),
              onPressed: () {
                _selectedClassIds
                  ..clear()
                  ..addAll(pre);
                _selectedClassNames
                  ..clear()
                  ..addAll(all
                      .where((c) => pre.contains(c.id))
                      .map((c) => c.name.isEmpty ? c.id : c.name));
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  // Coleta todos RAs das turmas selecionadas (para NOVOS materiais)
  Future<List<String>> _collectRAsFromSelectedClasses() async {
    return _collectRAsFromClassIds(_selectedClassIds);
  }

  // Coleta RAs a partir de uma lista arbitrária de turmas (para edição)
  Future<List<String>> _collectRAsFromClassIds(List<String> classIds) async {
    final ras = <String>{};
    for (final cid in classIds) {
      final qs = await FirebaseFirestore.instance
          .collection('classes')
          .doc(cid)
          .collection('students')
          .get();
      for (final s in qs.docs) {
        ras.add(s.id); // doc.id = RA
      }
    }
    return ras.toList()..sort();
  }

  // ============================================================================
  //                                   CRIAÇÃO
  // ============================================================================

  Future<void> _saveLink() async {
    final title = _title.text.trim();
    final subject = _subject.text.trim();
    final url = _linkUrl.text.trim();

    if (url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) {
      _snack('Informe uma URL válida (http/https).');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Salvando link...';
    });

    try {
      final allowedFromClasses = await _collectRAsFromSelectedClasses();

      await FirebaseFirestore.instance.collection('materials').add({
        'type': 'link',
        'title': title.isEmpty ? url : title,
        'subject': subject,
        'url': url,
        'fileName': null,
        'contentType': null,
        'size': null,
        'classIds': _selectedClassIds,
        'classNames': _selectedClassNames,
        'allowedRAs': allowedFromClasses,   // [] é aceito nas regras
        'ownerUid': _uid,                   // ✅ obrigatório
        'ownerEmail': _email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _title.clear();
      _subject.clear();
      _linkUrl.clear();
      _snack('Link salvo com sucesso!');
    } on FirebaseException catch (e) {
      if (mounted) _snack('Falha: ${e.code} — ${e.message}');
    } catch (e) {
      if (mounted) _snack('Falha ao salvar link: $e');
    } finally {
      if (mounted) {
        _busy = false;
        _status = null;
        setState(() {});
      }
    }
  }

  Future<void> _pickAndEmbedSmallFile() async {
    try {
      setState(() {
        _busy = true;
        _status = 'Selecionando arquivo...';
      });

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() {
          _busy = false;
          _status = null;
        });
        return;
      }

      final file = result.files.single;
      final Uint8List? bytes = file.bytes;
      final fileName = file.name;

      if (bytes == null) {
        throw Exception('Não foi possível ler o arquivo selecionado.');
      }
      if (bytes.lengthInBytes > kMaxInlineBytes) {
        throw Exception(
          'Arquivo muito grande (${_fmtBytes(bytes.lengthInBytes)}). '
          'Use até ~${_fmtBytes(kMaxInlineBytes)} para embutir. '
          'Para maiores, salve como LINK.',
        );
      }

      final title = _title.text.trim().isEmpty ? fileName : _title.text.trim();
      final subject = _subject.text.trim();
      final contentType = lookupMimeType(fileName) ?? 'application/octet-stream';

      setState(() => _status = 'Convertendo arquivo...');
      final b64 = base64Encode(bytes);

      setState(() => _status = 'Salvando no Firestore...');
      final allowedFromClasses = await _collectRAsFromSelectedClasses();

      await FirebaseFirestore.instance.collection('materials').add({
        'type': 'inline',
        'title': title,
        'subject': subject,
        'fileName': fileName,
        'contentType': contentType,
        'size': bytes.lengthInBytes,
        'data': b64, // bytes em base64
        'classIds': _selectedClassIds,
        'classNames': _selectedClassNames,
        'allowedRAs': allowedFromClasses,
        'ownerUid': _uid,            // ✅ obrigatório
        'ownerEmail': _email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _title.clear();
      _subject.clear();
      _snack('Arquivo embutido com sucesso!');
    } on FirebaseException catch (e) {
      if (mounted) _snack('Falha: ${e.code} — ${e.message}');
    } catch (e) {
      if (mounted) _snack('Falha ao embutir arquivo: $e');
    } finally {
      if (mounted) {
        _busy = false;
        _status = null;
        setState(() {});
      }
    }
  }

  // ============================================================================
  //                                   AÇÕES (utilitário legado)
  // ============================================================================

  Future<void> _openItem(Map<String, dynamic> data) async {
    // Mantido apenas como utilitário, não é mais chamado no onTap da lista.
    final type = (data['type'] ?? '').toString();

    if (type == 'link') {
      final url = (data['url'] ?? '').toString();
      if (url.isEmpty) return;
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank');
      } else {
        _snack('Não foi possível abrir o link.');
      }
      return;
    }

    if (type == 'inline') {
      final b64 = (data['data'] ?? '').toString();
      if (b64.isEmpty) return;

      final contentType = (data['contentType'] ?? 'application/octet-stream').toString();
      final fileName = (data['fileName'] ?? 'material').toString();
      final bytes = base64Decode(b64);

      await openInlineBytes(bytes, contentType, fileName: fileName);
      return;
    }

    _snack('Tipo de material desconhecido.');
  }

  Future<void> _showEditDialog(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final type = (data['type'] ?? '').toString();
    final owner = (data['ownerUid'] ?? '').toString();
    if (owner != _uid) {
      _snack('Somente o professor que criou pode editar.');
      return;
    }

    final titleCtrl = TextEditingController(text: (data['title'] ?? '').toString());
    final subjCtrl  = TextEditingController(text: (data['subject'] ?? '').toString());
    final urlCtrl   = TextEditingController(text: (data['url'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar material'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 8),
              TextField(controller: subjCtrl, decoration: const InputDecoration(labelText: 'Disciplina/Assunto')),
              if (type == 'link') ...[
                const SizedBox(height: 8),
                TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL (http/https)')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _editClassesForMaterial(doc),
            icon: const Icon(Icons.groups_2_outlined),
            label: const Text('Editar turmas'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar'),
            onPressed: () async {
              final newTitle = titleCtrl.text.trim();
              final newSubj  = subjCtrl.text.trim();
              final newUrl   = urlCtrl.text.trim();

              if (type == 'link' && newUrl.isNotEmpty &&
                  !(newUrl.startsWith('http://') || newUrl.startsWith('https://'))) {
                _snack('URL inválida. Use http/https.');
                return;
              }

              try {
                final payload = <String, dynamic>{'title': newTitle, 'subject': newSubj};
                if (type == 'link') payload['url'] = newUrl;
                await doc.reference.update(payload);
                if (mounted) { Navigator.pop(context); _snack('Material atualizado!'); }
              } on FirebaseException catch (e) {
                _snack('Falha: ${e.code} — ${e.message}');
              } catch (e) {
                _snack('Falha ao atualizar: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editClassesForMaterial(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final owner = (data['ownerUid'] ?? '').toString();
    if (owner != _uid) {
      _snack('Somente o professor que criou pode editar.');
      return;
    }

    var classesSnap = await FirebaseFirestore.instance
        .collection('classes')
        .where('ownerUid', isEqualTo: _uid)
        .orderBy('name')
        .get();

    var all = classesSnap.docs
        .map((d) => (id: d.id, name: (d['name'] ?? '').toString()))
        .toList();

    final preSelected = Set<String>.from(
      (data['classIds'] as List?)?.map((e) => e.toString()) ?? const [],
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Editar turmas do material'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await _showNewClassDialog();
                      classesSnap = await FirebaseFirestore.instance
                          .collection('classes')
                          .where('ownerUid', isEqualTo: _uid)
                          .orderBy('name')
                          .get();
                      setDlg(() {
                        all = classesSnap.docs
                            .map((d) => (id: d.id, name: (d['name'] ?? '').toString()))
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nova turma'),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in all)
                        CheckboxListTile(
                          value: preSelected.contains(c.id),
                          title: Text(c.name.isEmpty ? c.id : c.name),
                          onChanged: (v) => setDlg(() {
                            if (v == true) preSelected.add(c.id);
                            else preSelected.remove(c.id);
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar turmas'),
              onPressed: () async {
                try {
                  final chosen = preSelected.toList();
                  final chosenNames = all
                      .where((c) => preSelected.contains(c.id))
                      .map((c) => c.name.isEmpty ? c.id : c.name)
                      .toList();
                  final ras = await _collectRAsFromClassIds(chosen);

                  await doc.reference.update({
                    'classIds': chosen,
                    'classNames': chosenNames,
                    'allowedRAs': ras,
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    _snack('Turmas atualizadas!');
                  }
                } catch (e) {
                  _snack('Falha ao atualizar turmas: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMaterial(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final owner = (data['ownerUid'] ?? '').toString();
      if (owner != _uid) {
        _snack('Sem permissão para excluir este item.');
        return;
      }
      await doc.reference.delete();
      _snack('Material excluído.');
    } on FirebaseException catch (e) {
      _snack('Falha: ${e.code} — ${e.message}');
    } catch (e) {
      _snack('Erro ao excluir: $e');
    }
  }

  // ============================================================================
  //                                   UI
  // ============================================================================

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtBytes(int b) {
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '$b B';
  }

  String? _extractUrl(String text) {
    final r = RegExp(r'https?:\/\/[^\s\)]+');
    final m = r.firstMatch(text);
    return m?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isProf = (_materialsStream != null) && (_isProfessor == true);

    return Scaffold(
      appBar: AppBar(title: const Text('Materiais')),
      body: Column(
        children: [
          // Formulário só para professor
          if (isProf)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Título (opcional)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _subject,
                        decoration: const InputDecoration(labelText: 'Disciplina/Assunto (opcional)'),
                      ),

                      // ===== Seletor de turmas =====
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedClassIds.isEmpty
                                ? Colors.red.withOpacity(.35)
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.groups_2_outlined, size: 20),
                                const SizedBox(width: 8),
                                Text('Compartilhar com turmas',
                                    style: Theme.of(context).textTheme.titleMedium),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: _busy ? null : _pickClasses,
                                  icon: const Icon(Icons.list_alt),
                                  label: const Text('Selecionar turmas'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedClassIds.isEmpty)
                              Text(
                                'Nenhuma turma selecionada — os alunos não verão este material.',
                                style: TextStyle(
                                  color: Colors.red.withOpacity(.8),
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final name in _selectedClassNames)
                                    Chip(
                                      avatar: const Icon(Icons.class_outlined, size: 16),
                                      label: Text(name.isEmpty ? 'Turma' : name),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _linkUrl,
                              decoration: const InputDecoration(
                                labelText: 'URL (http/https)',
                                hintText: 'https://exemplo.com/arquivo.pdf',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _busy ? null : _saveLink,
                            icon: const Icon(Icons.add_link),
                            label: const Text('Salvar link'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickAndEmbedSmallFile,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Selecionar arquivo e salvar (até ~700KB)'),
                        ),
                      ),
                      if (_status != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Text(_status!),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // ======================= BUSCA + CHIPS =======================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por título...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Lista de materiais
          Expanded(
            child: _materialsStream == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _materialsStream,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Mostra link para criar índice se necessário
                      if (snap.hasError) {
                        final err = snap.error.toString();
                        final url = _extractUrl(err);
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Erro ao listar materiais:',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(err, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              if (url != null)
                                FilledButton.icon(
                                  onPressed: () async {
                                    final uri = Uri.parse(url);
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                      webOnlyWindowName: '_blank',
                                    );
                                  },
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Abrir link para criar índice'),
                                ),
                            ],
                          ),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('Nenhum material disponível.'));
                      }

                      // ---------------- Disciplinas distintas ----------------
                      final subjects = <String>{};
                      for (final d in docs) {
                        final subj = (d.data()['subject'] ?? '').toString().trim();
                        if (subj.isNotEmpty) subjects.add(subj);
                      }
                      final subjectsList = subjects.toList()..sort();

                      // ---------------- Filtros client-side ----------------
                      final term = _searchCtrl.text.trim().toLowerCase();
                      final filtered = docs.where((d) {
                        final data = d.data();
                        final subj = (data['subject'] ?? '').toString();
                        final title = (data['title'] ?? '').toString().toLowerCase();

                        final subjectOk = _selectedSubject == null || _selectedSubject == subj;
                        final searchOk = term.isEmpty || title.contains(term);
                        return subjectOk && searchOk;
                      }).toList();

                      return Column(
                        children: [
                          // Chips de disciplina
                          if (subjectsList.isNotEmpty)
                            SizedBox(
                              height: 46,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: const Text('Todas'),
                                      selected: _selectedSubject == null,
                                      onSelected: (_) => setState(() => _selectedSubject = null),
                                    ),
                                  ),
                                  ...subjectsList.map((s) => Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          label: Text(s),
                                          selected: _selectedSubject == s,
                                          onSelected: (_) => setState(() => _selectedSubject = s),
                                        ),
                                      )),
                                ],
                              ),
                            ),

                          // Lista filtrada
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final d = filtered[i];
                                final data = d.data();
                                final type = (data['type'] ?? '').toString();
                                final title = (data['title'] ?? 'Sem título').toString();
                                final subject = (data['subject'] ?? '').toString();

                                IconData icon;
                                String subtitle = subject;
                                if (type == 'link') {
                                  icon = Icons.link;
                                  if (subtitle.isEmpty) subtitle = (data['url'] ?? '').toString();
                                } else if (type == 'inline') {
                                  icon = Icons.insert_drive_file;
                                  if (subtitle.isEmpty) {
                                    final name = (data['fileName'] ?? '').toString();
                                    final size = (data['size'] ?? 0) as int;
                                    subtitle = '$name · ${_fmtBytes(size)}';
                                  }
                                } else {
                                  icon = Icons.help_outline;
                                }

                                return ListTile(
                                  leading: Icon(icon),
                                  title: Text(title),
                                  subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MaterialDetailsPage(ref: d.reference),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
