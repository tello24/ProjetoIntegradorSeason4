import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'grades_page.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  late final String _uid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _uid = u?.uid ?? '';
    if (_uid.isEmpty) return;

    _stream = FirebaseFirestore.instance
        .collection('activities')
        .where('ownerUid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _createOrEditActivity({DocumentReference? ref, Map<String, dynamic>? data}) async {
    final titleCtrl = TextEditingController(text: data?['title']?.toString() ?? '');
    final weightCtrl = TextEditingController(text: (data?['weight'] ?? 1).toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ref == null ? 'Nova atividade' : 'Editar atividade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Peso (ex.: 1, 2, 3)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final weight = num.tryParse(weightCtrl.text.replaceAll(',', '.')) ?? 1;
              if (title.isEmpty) return;

              final coll = FirebaseFirestore.instance.collection('activities');
              if (ref == null) {
                await coll.add({
                  'ownerUid': _uid,
                  'title': title,
                  'weight': weight,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                await ref.update({'title': title, 'weight': weight});
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteActivity(DocumentReference ref, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir atividade'),
        content: Text('Tem certeza que deseja excluir "$title"?\n'
            'As notas dessa atividade também serão removidas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;

    // apaga a activity e as notas ligadas (grades.activityRef == ref)
    final batch = FirebaseFirestore.instance.batch();
    final grades = await FirebaseFirestore.instance
        .collection('grades')
        .where('activityRef', isEqualTo: ref)
        .get();
    for (final g in grades.docs) {
      batch.delete(g.reference);
    }
    batch.delete(ref);
    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atividade excluída.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Atividades')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createOrEditActivity,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Sem atividades ainda.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();
              final title = (data['title'] ?? '').toString();
              final weight = (data['weight'] ?? 1);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(title),
                  subtitle: Text('Peso: $weight'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Notas',
                        icon: const Icon(Icons.calculate_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GradesPage(
                                activityRef: d.reference,
                                activityData: data,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _createOrEditActivity(ref: d.reference, data: data),
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteActivity(d.reference, title),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: docs.length,
          );
        },
      ),
    );
  }
}