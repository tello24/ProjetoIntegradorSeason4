import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// IO por padrão; no web usa Blob/anchor
import '../utils/open_inline_io.dart'
  if (dart.library.html) '../utils/open_inline_web.dart';

class MaterialDetailsPage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> ref;
  const MaterialDetailsPage({super.key, required this.ref});

  @override
  State<MaterialDetailsPage> createState() => _MaterialDetailsPageState();
}

class _MaterialDetailsPageState extends State<MaterialDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do material')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }

          final doc = snap.data;
          if (doc == null || !doc.exists) {
            return const Center(child: Text('Material não encontrado.'));
          }

          final data = doc.data()!;
          final type = (data['type'] ?? '').toString(); // "link" | "inline"
          final title = (data['title'] ?? 'Sem título').toString();
          final subject = (data['subject'] ?? '').toString();
          final ownerEmail = (data['ownerEmail'] ?? '').toString();
          final ownerUid = (data['ownerUid'] ?? '').toString();
          final fileName = (data['fileName'] ?? '').toString();
          final size = (data['size'] ?? 0) as int;
          final url = (data['url'] ?? '').toString();
          final classNames = ((data['classNames'] as List?)?.map((e) => e.toString()).toList() ?? const []);
          final createdAt = data['createdAt'];
          final dateStr = _fmtDate(createdAt);

          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final isMine = currentUid != null && currentUid == ownerUid;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),

                // Sub-infos
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (subject.isNotEmpty)
                      _InfoChip(icon: Icons.menu_book_outlined, label: 'Disciplina: $subject'),
                    _InfoChip(
                      icon: Icons.person_outline,
                      label: ownerEmail.isEmpty ? 'Professor: —' : 'Professor: $ownerEmail',
                    ),
                    if (dateStr != null)
                      _InfoChip(icon: Icons.event_outlined, label: 'Data: $dateStr'),
                    _InfoChip(
                      icon: type == 'link' ? Icons.link : Icons.insert_drive_file,
                      label: 'Tipo: $type',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (classNames.isNotEmpty) ...[
                  Text('Turmas', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in classNames)
                        Chip(avatar: const Icon(Icons.class_outlined, size: 16), label: Text(n)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Se for arquivo embutido, mostrar nome e tamanho
                if (type == 'inline') ...[
                  _KeyValue('Arquivo', fileName.isEmpty ? '—' : fileName),
                  _KeyValue('Tamanho', _fmtBytes(size)),
                  const SizedBox(height: 16),
                ],

                // Ações principais
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: Text(type == 'link' ? 'Abrir link' : 'Abrir arquivo'),
                        onPressed: () => _open(context, data),
                      ),
                    ),
                  ],
                ),

                // Ações do professor dono
                if (isMine) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                          onPressed: () => _showEditDialog(data),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.groups_2_outlined),
                          label: const Text('Editar turmas'),
                          onPressed: () => _editClassesForMaterial(data),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Excluir material'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: _deleteMaterial,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================== Ações ==============================

  Future<void> _open(BuildContext context, Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    if (type == 'link') {
      final url = (data['url'] ?? '').toString();
      if (url.isEmpty) {
        _toast(context, 'Link vazio.');
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri == null) {
        _toast(context, 'URL inválida.');
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank');
      if (!ok) _toast(context, 'Não foi possível abrir o link.');
      return;
    }

    if (type == 'inline') {
      final b64 = (data['data'] ?? '').toString();
      if (b64.isEmpty) {
        _toast(context, 'Arquivo embutido vazio.');
        return;
      }
      final bytes = base64Decode(b64);
      final contentType = (data['contentType'] ?? 'application/octet-stream').toString();
      final fileName = (data['fileName'] ?? 'material').toString();
      await openInlineBytes(bytes, contentType, fileName: fileName);
      return;
    }

    _toast(context, 'Tipo de material não suportado: $type');
  }

  Future<void> _showEditDialog(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
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
                _toast(context, 'URL inválida. Use http/https.');
                return;
              }

              try {
                final payload = <String, dynamic>{
                  'title': newTitle,
                  'subject': newSubj,
                };
                if (type == 'link') payload['url'] = newUrl;

                await widget.ref.update(payload);
                if (mounted) { Navigator.pop(context); _toast(context, 'Material atualizado!'); }
              } on FirebaseException catch (e) {
                _toast(context, 'Falha: ${e.code} — ${e.message}');
              } catch (e) {
                _toast(context, 'Falha ao atualizar: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editClassesForMaterial(Map<String, dynamic> data) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final ownerUid = (data['ownerUid'] ?? '').toString();
    if (currentUid == null || currentUid != ownerUid) {
      _toast(context, 'Somente o professor que criou pode editar turmas.');
      return;
    }

    var classesSnap = await FirebaseFirestore.instance
        .collection('classes')
        .where('ownerUid', isEqualTo: ownerUid)
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
                      await _showNewClassDialog(ownerUid);
                      classesSnap = await FirebaseFirestore.instance
                          .collection('classes')
                          .where('ownerUid', isEqualTo: ownerUid)
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

                  await widget.ref.update({
                    'classIds': chosen,
                    'classNames': chosenNames,
                    'allowedRAs': ras,
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    _toast(context, 'Turmas atualizadas!');
                  }
                } catch (e) {
                  _toast(context, 'Falha ao atualizar turmas: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMaterial() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir material?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final snap = await widget.ref.get();
      final ownerUid = (snap.data()?['ownerUid'] ?? '').toString();
      if (currentUid == null || currentUid != ownerUid) {
        _toast(context, 'Sem permissão para excluir este item.');
        return;
      }
      await widget.ref.delete();
      if (mounted) {
        Navigator.maybePop(context);
        _toast(context, 'Material excluído.');
      }
    } on FirebaseException catch (e) {
      _toast(context, 'Falha: ${e.code} — ${e.message}');
    } catch (e) {
      _toast(context, 'Erro ao excluir: $e');
    }
  }

  // ============================== helpers ===============================

  Future<void> _showNewClassDialog(String ownerUid) async {
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
            decoration: const InputDecoration(labelText: 'Nome da turma (ex.: T2SUB01)'),
            onSubmitted: (_) async {
              if (saving) return;
              setDlg(() => saving = true);
              await FirebaseFirestore.instance.collection('classes').add({
                'name': ctrl.text.trim(),
                'ownerUid': ownerUid,
                'ownerEmail': FirebaseAuth.instance.currentUser?.email ?? '',
                'createdAt': FieldValue.serverTimestamp(),
              });
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
                      await FirebaseFirestore.instance.collection('classes').add({
                        'name': ctrl.text.trim(),
                        'ownerUid': ownerUid,
                        'ownerEmail': FirebaseAuth.instance.currentUser?.email ?? '',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
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

  String? _fmtDate(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    } catch (_) {}
    return null;
  }

  static String _fmtBytes(int b) {
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '$b B';
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String k;
  final String v;
  const _KeyValue(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
