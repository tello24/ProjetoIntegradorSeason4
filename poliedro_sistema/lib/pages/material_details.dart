import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// IO por padrão; no web usa Blob/anchor
import '../utils/open_inline_io.dart'
  if (dart.library.html) '../utils/open_inline_web.dart';

class MaterialDetailsPage extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> ref;
  const MaterialDetailsPage({super.key, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do material')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
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
          final fileName = (data['fileName'] ?? '').toString();
          final size = (data['size'] ?? 0) as int;
          final url = (data['url'] ?? '').toString();
          final classNames = ((data['classNames'] as List?)?.map((e) => e.toString()).toList() ?? const []);
          final createdAt = data['createdAt'];
          final dateStr = _fmtDate(createdAt);

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
                    _InfoChip(icon: Icons.person_outline, label: ownerEmail.isEmpty ? 'Professor: —' : 'Professor: $ownerEmail'),
                    if (dateStr != null) _InfoChip(icon: Icons.event_outlined, label: 'Data: $dateStr'),
                    _InfoChip(icon: type == 'link' ? Icons.link : Icons.insert_drive_file, label: 'Tipo: $type'),
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

                // Ações
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
              ],
            ),
          );
        },
      ),
    );
  }

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