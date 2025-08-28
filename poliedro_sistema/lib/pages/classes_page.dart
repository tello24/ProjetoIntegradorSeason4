import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});
  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final _nameCtrl = TextEditingController();
  late final String _uid;
  late final String _email;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
      });
      return;
    }
    _uid = u.uid;
    _email = u.email ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // -------------------- CRUD TURMA --------------------

  Future<void> _createClass() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Informe o nome da turma.');
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('classes').add({
        'name': name,
        'ownerUid': _uid,                          // ✅ obrigatório nas regras
        'ownerEmail': _email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameCtrl.clear();
      _snack('Turma "$name" criada!');
    } on FirebaseException catch (e) {
      _snack('Falha: ${e.code} — ${e.message}');
    } catch (e) {
      _snack('Erro: $e');
    }
  }

  Future<void> _editName(DocumentReference ref, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear turma'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              try {
                await ref.update({'name': ctrl.text.trim()});
                if (mounted) Navigator.pop(context);
                _snack('Turma atualizada!');
              } on FirebaseException catch (e) {
                _snack('Falha: ${e.code} — ${e.message}');
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClass(DocumentReference ref) async {
    try {
      // Observação: Firestore NÃO apaga subcoleções automaticamente.
      // Se quiser, faça uma limpeza assíncrona aqui antes.
      await ref.delete(); // regras permitem se você for o dono
      _snack('Turma excluída.');
    } on FirebaseException catch (e) {
      _snack('Erro ao excluir: ${e.code} — ${e.message}');
    }
  }

  // -------------------- GERENCIAR RAs --------------------

  Future<void> _manageStudents(String classId) async {
    final raCtrl = TextEditingController();

    // carrega RAs atuais
    final current = await FirebaseFirestore.instance
        .collection('classes').doc(classId).collection('students').get();
    final ras = current.docs.map((d) => d.id).toList()..sort();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Alunos da turma (RAs)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: raCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Adicionar RA (7 dígitos)'),
                onSubmitted: (_) async => _addRa(classId, raCtrl, ras, setDlg),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ra in ras)
                      Chip(
                        label: Text(ra),
                        onDeleted: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('classes').doc(classId)
                                .collection('students').doc(ra).delete();
                            setDlg(() => ras.remove(ra));
                            _snack('RA $ra removido.');
                          } on FirebaseException catch (e) {
                            _snack('Falha: ${e.code} — ${e.message}');
                          }
                        },
                      ),
                  ],
                ),
              ),
              if (ras.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Nenhum RA cadastrado ainda.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
            FilledButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Adicionar RA'),
              onPressed: () async => _addRa(classId, raCtrl, ras, setDlg),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addRa(
    String classId,
    TextEditingController raCtrl,
    List<String> ras,
    void Function(void Function()) setDlg,
  ) async {
    final ra = raCtrl.text.trim();
    if (!RegExp(r'^\d{7}$').hasMatch(ra)) {
      _snack('RA inválido. Use exatamente 7 dígitos.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('students')
          .doc(ra) // o id do doc é o RA
          .set({'addedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      setDlg(() {
        if (!ras.contains(ra)) ras.add(ra);
        ras.sort();
        raCtrl.clear();
      });
      _snack('RA $ra adicionado!');
    } on FirebaseException catch (e) {
      _snack('Falha: ${e.code} — ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uidShort = _uid.length > 8 ? '${_uid.substring(0, 6)}…' : _uid;

    // Dica: se o Firestore pedir índice, remova .orderBy('name') ou crie o índice.
    final stream = FirebaseFirestore.instance
        .collection('classes')
        .where('ownerUid', isEqualTo: _uid)
        .orderBy('name') // seguro e legível; pode remover se preferir sem índice
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Turmas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Logado: $_email  (uid: $uidShort)',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome da turma (ex.: 3ºB Matemática)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _createClass,
                  icon: const Icon(Icons.add),
                  label: const Text('Criar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro: ${snap.error}'),
                    ),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Nenhuma turma ainda.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data = d.data();
                    final name = (data['name'] ?? '').toString();
                    return ListTile(
                      leading: const Icon(Icons.class_outlined),
                      title: Text(name.isEmpty ? '(sem nome)' : name),
                      subtitle: Text('id: ${d.id}'),
                      onTap: () => _manageStudents(d.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Renomear',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editName(d.reference, name),
                          ),
                          IconButton(
                            tooltip: 'Excluir',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteClass(d.reference),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
