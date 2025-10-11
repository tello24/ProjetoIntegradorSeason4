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

  String? _filterClassId; // filtro opcional por turma

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _uid = u?.uid ?? '';
    if (_uid.isEmpty) return;
    _reloadStream();
  }

  void _reloadStream() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('activities')
        .where('ownerUid', isEqualTo: _uid);

    if (_filterClassId != null) {
      q = q.where('classId', isEqualTo: _filterClassId);
    }

    _stream = q.orderBy('createdAt', descending: true).snapshots();
    setState(() {});
  }

  Future<void> _createOrEditActivity({
    DocumentReference? ref,
    Map<String, dynamic>? data,
  }) async {
    final titleCtrl = TextEditingController(
      text: data?['title']?.toString() ?? '',
    );
    final subjectCtrl = TextEditingController(
      text: data?['subject']?.toString() ?? '',
    );
    final weightCtrl = TextEditingController(
      text: (data?['weight'] ?? 1).toString(),
    );

    String? classId = data?['classId']?.toString();
    String? className = data?['className']?.toString();
    DateTime? dueDate = (data?['dueDate'] is Timestamp)
        ? (data?['dueDate'] as Timestamp).toDate()
        : null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        String? localClassId = classId;
        String? localClassName = className;
        DateTime? localDue = dueDate;

        final formKey = GlobalKey<FormState>();

        return StatefulBuilder(
          builder: (context, setLocal) {
            final classesQ = FirebaseFirestore.instance
                .collection('classes')
                .where('ownerUid', isEqualTo: _uid)
                .orderBy('name');

            Future<void> _pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: localDue ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 3),
              );
              if (picked != null) setLocal(() => localDue = picked);
            }

            Future<void> _onSave() async {
              if (!formKey.currentState!.validate()) return;
              final title = titleCtrl.text.trim();
              final subject = subjectCtrl.text.trim();
              final weight =
                  num.tryParse(weightCtrl.text.replaceAll(',', '.')) ?? 1;

              final coll = FirebaseFirestore.instance.collection('activities');
              final payload = <String, dynamic>{
                'ownerUid': _uid,
                'classId': localClassId,
                'className': localClassName,
                'subject': subject,
                'title': title,
                'weight': weight,
                'dueDate': localDue != null
                    ? Timestamp.fromDate(localDue!)
                    : null,
              };

              if (ref == null) {
                payload['createdAt'] = FieldValue.serverTimestamp();
                await coll.add(payload);
              } else {
                await ref.update(payload);
              }
              if (mounted) Navigator.pop(context);
            }

            return AlertDialog(
              title: Text(ref == null ? 'Nova atividade' : 'Editar atividade'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Turma
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: classesQ.snapshots(),
                        builder: (context, s) {
                          final docs = s.data?.docs ?? [];
                          final items = docs
                              .map(
                                (d) => DropdownMenuItem<String>(
                                  value: d.id,
                                  child: Text(d['name'] ?? d.id),
                                ),
                              )
                              .toList();
                          return DropdownButtonFormField<String>(
                            value: localClassId,
                            items: items,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Turma',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                v == null ? 'Selecione a turma' : null,
                            onChanged: (v) {
                              final name = docs
                                  .firstWhere((e) => e.id == v)
                                  .data()['name'];
                              setLocal(() {
                                localClassId = v;
                                localClassName = name;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Matéria
                      TextFormField(
                        controller: subjectCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Matéria',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe a matéria'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Título
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título da atividade',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe o título'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Peso
                      TextFormField(
                        controller: weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Peso (ex.: 1, 2, 3)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = num.tryParse(
                            (v ?? '').replaceAll(',', '.'),
                          );
                          if (n == null) return 'Peso inválido';
                          if (n <= 0) return 'Peso deve ser > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Data de entrega
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event),
                              label: Text(
                                localDue == null
                                    ? 'Selecionar data de entrega'
                                    : 'Entrega: ${_fmtDate(localDue!)}',
                              ),
                              onPressed: _pickDate,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(onPressed: _onSave, child: const Text('Salvar')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteActivity(DocumentReference ref, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir atividade'),
        content: Text(
          'Tem certeza que deseja excluir "$title"?\n'
          'As notas dessa atividade também serão removidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Atividade excluída.')));
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
      body: Column(
        children: [
          // Filtro por Turma
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .where('ownerUid', isEqualTo: _uid)
                  .orderBy('name')
                  .snapshots(),
              builder: (context, s) {
                final docs = s.data?.docs ?? [];
                return DropdownButtonFormField<String>(
                  value: _filterClassId,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por turma',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas as turmas'),
                    ),
                    ...docs.map(
                      (d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d['name'] ?? d.id),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    _filterClassId = v;
                    _reloadStream();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    final subject = (data['subject'] ?? '').toString();
                    final weight = (data['weight'] ?? 1);
                    final classNm = (data['className'] ?? data['classId'] ?? '')
                        .toString();
                    final due = (data['dueDate'] is Timestamp)
                        ? (data['dueDate'] as Timestamp).toDate()
                        : null;

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.assignment_outlined),
                        title: Text(title.isEmpty ? 'Atividade' : title),
                        subtitle: Text(
                          [
                            if (subject.isNotEmpty) 'Matéria: $subject',
                            if (classNm.isNotEmpty) 'Turma: $classNm',
                            'Peso: $weight',
                            if (due != null) 'Entrega: ${_fmtDate(due)}',
                          ].join(' · '),
                        ),
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
                                      activityData:
                                          data, // contém classId, className, subject, weight etc.
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Editar',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _createOrEditActivity(
                                ref: d.reference,
                                data: data,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Excluir',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _deleteActivity(d.reference, title),
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
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
