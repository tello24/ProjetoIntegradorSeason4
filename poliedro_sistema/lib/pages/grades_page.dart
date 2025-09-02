import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GradesPage extends StatefulWidget {
  final DocumentReference activityRef;
  final Map<String, dynamic> activityData;

  const GradesPage({
    super.key,
    required this.activityRef,
    required this.activityData,
  });

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  final _uidCtrl = TextEditingController();
  final _raCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  String? _activeFilter; // 'uid' | 'ra' | 'email' | null

  @override
  void dispose() {
    _uidCtrl.dispose();
    _raCtrl.dispose();
    _emailCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('grades')
        .where('activityRef', isEqualTo: widget.activityRef)
        .orderBy('createdAt', descending: true);

    // um filtro por vez para casar com os índices existentes
    switch (_activeFilter) {
      case 'uid':
        final uid = _uidCtrl.text.trim();
        if (uid.isNotEmpty) q = q.where('studentUid', isEqualTo: uid);
        break;
      case 'ra':
        final ra = _raCtrl.text.trim();
        if (ra.isNotEmpty) q = q.where('studentRa', isEqualTo: ra);
        break;
      case 'email':
        final email = _emailCtrl.text.trim();
        if (email.isNotEmpty) q = q.where('studentEmail', isEqualTo: email);
        break;
      default:
        // sem filtro
        break;
    }
    return q;
  }

  Future<void> _saveGrade() async {
    final value = num.tryParse(_notaCtrl.text.replaceAll(',', '.'));
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota inválida.')));
      return;
    }

    final u = FirebaseAuth.instance.currentUser;
    final ownerUid = u?.uid ?? '';

    await FirebaseFirestore.instance.collection('grades').add({
      'activityRef': widget.activityRef,
      'activityTitle': widget.activityData['title'],
      'weight': widget.activityData['weight'] ?? 1,
      'ownerUid': ownerUid,
      // campos do aluno (preencha qualquer um: uid/ra/email)
      'studentUid': _uidCtrl.text.trim().isEmpty ? null : _uidCtrl.text.trim(),
      'studentRa': _raCtrl.text.trim().isEmpty ? null : _raCtrl.text.trim(),
      'studentEmail': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'value': value,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _notaCtrl.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota lançada.')));
  }

  Future<void> _editGrade(DocumentReference ref, num current) async {
    final ctrl = TextEditingController(text: current.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar nota'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nova nota'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) return;

    final v = num.tryParse(ctrl.text.replaceAll(',', '.'));
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valor inválido.')));
      return;
    }
    await ref.update({'value': v});
  }

  Future<void> _deleteGrade(DocumentReference ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir nota'),
        content: const Text('Confirma a exclusão desta nota?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) await ref.delete();
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.activityData['title'] ?? '').toString();
    final weight = widget.activityData['weight'] ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notas · $title'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Chip(label: Text('Peso $weight')),
          ),
        ],
      ),
      body: Column(
        children: [
          // Lançar nota
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _uidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'UID do aluno (opcional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _activeFilter = 'uid'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _raCtrl,
                    decoration: const InputDecoration(
                      labelText: 'RA (opcional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _activeFilter = 'ra'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _notaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nota',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saveGrade,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'E-mail do aluno (opcional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _activeFilter = 'email'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _activeFilter = null),
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Limpar filtro'),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          // Lista de notas
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Erro ao carregar notas:\n${snap.error}'));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Sem notas registradas.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final x = d.data();
                    final value = x['value'] ?? 0;
                    final uid = x['studentUid'] ?? '';
                    final ra = x['studentRa'] ?? '';
                    final email = x['studentEmail'] ?? '';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text('Nota: $value'),
                        subtitle: Text([
                          if (uid.toString().isNotEmpty) 'UID: $uid',
                          if (ra.toString().isNotEmpty) 'RA: $ra',
                          if (email.toString().isNotEmpty) 'Email: $email',
                        ].join(' · ')),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Editar nota',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editGrade(d.reference, value),
                            ),
                            IconButton(
                              tooltip: 'Excluir nota',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteGrade(d.reference),
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
}
