import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

// IO por padrão; no web usa Blob/anchor
import '../utils/open_inline_io.dart'
    if (dart.library.html) '../utils/open_inline_web.dart';

// Tela de detalhes
import 'material_details.dart';

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});
  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  // --------- sessão/role ---------
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

      Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
        'materials',
      );

      if (_isProfessor) {
        // professor: vê apenas os próprios
        q = q.where('ownerUid', isEqualTo: _uid);
      } else {
        // aluno: vê apenas os que têm seu RA autorizado
        q = q.where('allowedRAs', arrayContains: _studentRa);
      }

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

  // ============================================================================ UI helpers

  InputDecoration _dec(String hint, {IconData? icon, String? hint2}) {
    return InputDecoration(
      hintText: hint2 ?? hint,
      prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
      filled: true,
      fillColor: Colors.white.withOpacity(.06),
      hintStyle: const TextStyle(color: Colors.white60),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white54),
      ),
    );
  }

  // Campos escuros para DIALOG (evita “branco no branco”)
  InputDecoration _darkField(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withOpacity(.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white54),
      ),
    );
  }

  // Container de diálogo dark
  Widget _darkDialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1830),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: content,
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      actions: actions
          .map(
            (w) => Theme(
              data: ThemeData(
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(.12),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              child: w,
            ),
          )
          .toList(),
    );
  }

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

  // ============================================================================ TURMAS

  Future<void> _showNewClassDialog() async {
    final ctrl = TextEditingController();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => _darkDialog(
          title: 'Nova turma',
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: _darkField('Nome da turma (ex.: T2SUB01)'),
              onSubmitted: (_) async {
                if (saving) return;
                setDlg(() => saving = true);
                await _createClass(ctrl.text);
                setDlg(() => saving = false);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
        'ownerUid': _uid, // ✅ regras exigem isto
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
        builder: (ctx, setDlg) => _darkDialog(
          title: 'Selecionar turmas',
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
                            .map(
                              (d) => (
                                id: d.id,
                                name: (d['name'] ?? '').toString(),
                              ),
                            )
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Nova turma',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in all)
                        CheckboxListTile(
                          value: pre.contains(c.id),
                          activeColor: Colors.white,
                          checkColor: Colors.black,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            c.name.isEmpty ? c.id : c.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onChanged: (v) => setDlg(() {
                            if (v == true)
                              pre.add(c.id);
                            else
                              pre.remove(c.id);
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Usar selecionadas'),
              onPressed: () {
                _selectedClassIds
                  ..clear()
                  ..addAll(pre);
                _selectedClassNames
                  ..clear()
                  ..addAll(
                    all
                        .where((c) => pre.contains(c.id))
                        .map((c) => c.name.isEmpty ? c.id : c.name),
                  );
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

  // ============================================================================ CRIAÇÃO

  Future<void> _saveLink() async {
    final title = _title.text.trim();
    final subject = _subject.text.trim();
    final url = _linkUrl.text.trim();

    if (url.isEmpty ||
        !(url.startsWith('http://') || url.startsWith('https://'))) {
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
        'allowedRAs': allowedFromClasses, // [] é aceito nas regras
        'ownerUid': _uid, // ✅ obrigatório
        'ownerEmail': _email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _title.clear();
      _subject.clear();
      _linkUrl.clear();
      _selectedClassIds.clear();
      _selectedClassNames.clear();
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
      final contentType =
          lookupMimeType(fileName) ?? 'application/octet-stream';

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
        'ownerUid': _uid, // ✅ obrigatório
        'ownerEmail': _email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _title.clear();
      _subject.clear();
      _selectedClassIds.clear();
      _selectedClassNames.clear();
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

  // ============================================================================ EDIÇÃO/EXCLUSÃO

  Future<void> _showEditDialog(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final type = (data['type'] ?? '').toString();
    final owner = (data['ownerUid'] ?? '').toString();
    if (owner != _uid) {
      _snack('Somente o professor que criou pode editar.');
      return;
    }

    final titleCtrl = TextEditingController(
      text: (data['title'] ?? '').toString(),
    );
    final subjCtrl = TextEditingController(
      text: (data['subject'] ?? '').toString(),
    );
    final urlCtrl = TextEditingController(text: (data['url'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Editar material',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _darkField('Título'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subjCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _darkField('Disciplina/Assunto'),
              ),
              if (type == 'link') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _darkField('URL (http/https)'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar'),
            onPressed: () async {
              final newTitle = titleCtrl.text.trim();
              final newSubj = subjCtrl.text.trim();
              final newUrl = urlCtrl.text.trim();

              if (type == 'link' &&
                  newUrl.isNotEmpty &&
                  !(newUrl.startsWith('http://') ||
                      newUrl.startsWith('https://'))) {
                _snack('URL inválida. Use http/https.');
                return;
              }

              try {
                final payload = <String, dynamic>{
                  'title': newTitle,
                  'subject': newSubj,
                };
                if (type == 'link') payload['url'] = newUrl;
                await doc.reference.update(payload);
                if (mounted) {
                  Navigator.pop(context);
                  _snack('Material atualizado!');
                }
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
        builder: (ctx, setDlg) => _darkDialog(
          title: 'Editar turmas do material',
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
                            .map(
                              (d) => (
                                id: d.id,
                                name: (d['name'] ?? '').toString(),
                              ),
                            )
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Nova turma',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in all)
                        CheckboxListTile(
                          value: preSelected.contains(c.id),
                          activeColor: Colors.white,
                          checkColor: Colors.black,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            c.name.isEmpty ? c.id : c.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onChanged: (v) => setDlg(() {
                            if (v == true)
                              preSelected.add(c.id);
                            else
                              preSelected.remove(c.id);
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
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

  // ============================================================================ BUILD

  @override
  Widget build(BuildContext context) {
    if (!_loadedUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isProf = (_materialsStream != null) && (_isProfessor == true);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,

        // botão VOLTAR no topo esquerdo — mesmo componente e tamanho
        leadingWidth: 136,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
          child: SizedBox(
            width: 136,
            child: _BackButton(onTap: () => Navigator.maybePop(context)),
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              }
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // === FUNDO IGUAL ALUNO ===
          const _Bg(),

          Column(
            children: [
              // Busca
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec(
                      'Buscar por título...',
                      icon: Icons.search,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),

              // Formulário só para professor
              if (isProf)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: _Glass(
                    radius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Novo material',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _title,
                                style: const TextStyle(color: Colors.white),
                                decoration: _dec(
                                  'Título (opcional)',
                                  icon: Icons.title,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _subject,
                                style: const TextStyle(color: Colors.white),
                                decoration: _dec(
                                  'Disciplina/Assunto (opcional)',
                                  icon: Icons.menu_book_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Glass(
                          radius: 14,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.groups_2_outlined,
                                    size: 18,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Compartilhar com turmas',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: Colors.white),
                                  ),
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
                                const Text(
                                  'Nenhuma turma selecionada — os alunos não verão este material.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final name in _selectedClassNames)
                                      _TagPill(
                                        text: name.isEmpty ? 'Turma' : name,
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _linkUrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: _dec(
                                  'URL (http/https)',
                                  icon: Icons.link,
                                  hint2: 'https://exemplo.com/arquivo.pdf',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: _busy ? null : _saveLink,
                              icon: const Icon(Icons.add_link),
                              label: const Text('Salvar link'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _pickAndEmbedSmallFile,
                            icon: const Icon(Icons.attach_file),
                            label: const Text(
                              'Selecionar arquivo e salvar (até ~700KB)',
                            ),
                          ),
                        ),
                        if (_status != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _status!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // LISTA + FILTROS (sem botão Voltar aqui)
              Expanded(
                child: _materialsStream == null
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _materialsStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          // Erro/índice
                          if (snap.hasError) {
                            final err = snap.error.toString();
                            final url = _extractUrl(err);
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Erro ao listar materiais:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    err,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
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
                                      label: const Text(
                                        'Abrir link para criar índice',
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }

                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'Nenhum material disponível.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          }

                          // disciplinas
                          final subjects = <String>{};
                          for (final d in docs) {
                            final subj = (d.data()['subject'] ?? '')
                                .toString()
                                .trim();
                            if (subj.isNotEmpty) subjects.add(subj);
                          }
                          final subjectsList = subjects.toList()..sort();

                          // filtros client-side
                          final term = _searchCtrl.text.trim().toLowerCase();
                          final filtered = docs.where((d) {
                            final data = d.data();
                            final subj = (data['subject'] ?? '').toString();
                            final title = (data['title'] ?? '')
                                .toString()
                                .toLowerCase();
                            final subjectOk =
                                _selectedSubject == null ||
                                _selectedSubject == subj;
                            final searchOk =
                                term.isEmpty || title.contains(term);
                            return subjectOk && searchOk;
                          }).toList();

                          return Column(
                            children: [
                              // === CHIPS (apenas filtros) ===
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  6,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _FilterPill(
                                      text: 'Todas',
                                      selected: _selectedSubject == null,
                                      onTap: () => setState(
                                        () => _selectedSubject = null,
                                      ),
                                    ),
                                    ...subjectsList.map(
                                      (s) => _FilterPill(
                                        text: s,
                                        selected: _selectedSubject == s,
                                        onTap: () => setState(
                                          () => _selectedSubject = s,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Lista
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    16,
                                  ),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, i) {
                                    final d = filtered[i];
                                    final data = d.data();
                                    final type = (data['type'] ?? '')
                                        .toString();
                                    final title =
                                        (data['title'] ?? 'Sem título')
                                            .toString();
                                    final subject = (data['subject'] ?? '')
                                        .toString();

                                    IconData icon;
                                    String subtitle = subject;
                                    if (type == 'link') {
                                      icon = Icons.link;
                                      if (subtitle.isEmpty)
                                        subtitle = (data['url'] ?? '')
                                            .toString();
                                    } else if (type == 'inline') {
                                      icon = Icons.insert_drive_file;
                                      if (subtitle.isEmpty) {
                                        final name = (data['fileName'] ?? '')
                                            .toString();
                                        final size = (data['size'] ?? 0) as int;
                                        subtitle = '$name · ${_fmtBytes(size)}';
                                      }
                                    } else {
                                      icon = Icons.help_outline;
                                    }

                                    return _Glass(
                                      radius: 16,
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                        leading: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF3E5FBF),
                                                Color(0xFF7A45C8),
                                              ],
                                            ),
                                          ),
                                          child: Icon(
                                            icon,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        subtitle: subtitle.isNotEmpty
                                            ? Text(
                                                subtitle,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              )
                                            : null,
                                        trailing: _isProfessor
                                            ? PopupMenuButton<String>(
                                                tooltip: 'Ações',
                                                color: const Color(0xFF1A1830),
                                                surfaceTintColor:
                                                    Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                elevation: 6,
                                                offset: const Offset(0, 8),
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                  color: Colors.white70,
                                                ),
                                                onSelected: (v) async {
                                                  if (v == 'edit')
                                                    await _showEditDialog(d);
                                                  if (v == 'classes')
                                                    await _editClassesForMaterial(
                                                      d,
                                                    );
                                                  if (v == 'delete')
                                                    await _deleteMaterial(d);
                                                },
                                                itemBuilder: (ctx) => [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: _MenuTile(
                                                      icon: Icons.edit_outlined,
                                                      label: 'Editar',
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'classes',
                                                    child: _MenuTile(
                                                      icon: Icons
                                                          .groups_2_outlined,
                                                      label: 'Editar turmas',
                                                    ),
                                                  ),
                                                  const PopupMenuDivider(),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: _MenuTile(
                                                      icon:
                                                          Icons.delete_outline,
                                                      label: 'Excluir',
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                color: Colors.white70,
                                                size: 18,
                                              ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  MaterialDetailsPage(
                                                    ref: d.reference,
                                                  ),
                                            ),
                                          );
                                        },
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
        ],
      ),
    );
  }
}

/* ========================= FUNDO (igual AlunoHome) ========================= */

class _Bg extends StatelessWidget {
  const _Bg();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/poliedro.png'),
              fit: BoxFit.cover,
            ),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0B091B).withOpacity(.88),
                const Color(0xFF0B091B).withOpacity(.88),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Center(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/images/iconePoliedro.png',
                width: _watermarkSize(context),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _watermarkSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 640) return (w * 1.15).clamp(420.0, 760.0);
    if (w < 1000) return (w * 0.82).clamp(520.0, 780.0);
    return (w * 0.55).clamp(700.0, 900.0);
  }
}

/* ========================= Glass / Pílulas / Voltar ========================= */

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
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = selected
        ? const LinearGradient(colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)])
        : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? Colors.white.withOpacity(.10) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white24 : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
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

/// Pílula para mostrar turmas selecionadas (contraste forte)
class _TagPill extends StatelessWidget {
  final String text;
  const _TagPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.class_outlined, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

/// Item estilizado para popup menu (ícone alinhado — inclui lixeira)
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuTile({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Row(
      children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: c, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
