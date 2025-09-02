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
  bool _saving = false;

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

    // Um filtro por vez para casar com os índices existentes
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
        break;
    }
    return q;
  }

  Future<String?> _resolveRA() async {
    // 1) Se RA foi digitado, usa ele
    final ra = _raCtrl.text.trim();
    if (ra.isNotEmpty) return ra;

    // 2) Se veio UID, buscamos o RA no users/{uid}
    final uid = _uidCtrl.text.trim();
    if (uid.isNotEmpty) {
      final u = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return u.data()?['ra']?.toString();
    }

    // 3) Se veio e-mail, tentamos achar o usuário pelo campo 'email' (se existir no seu modelo)
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty) {
      final s = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (s.docs.isNotEmpty) {
        return s.docs.first.data()['ra']?.toString();
      }
    }

    return null;
  }

  Future<void> _saveGrade() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // 0) Dados básicos da atividade
      final activityId = widget.activityRef.id;
      final classId = widget.activityData['classId'];
      final className = widget.activityData['className'];
      final subject = widget.activityData['subject'];
      final title = (widget.activityData['title'] ?? 'Atividade').toString();
      final weight = (widget.activityData['weight'] ?? 1).toDouble();

      // Se a atividade antiga não tiver turma, avisa e sai
      if (classId == null || classId.toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta atividade não tem turma definida. Edite a atividade e selecione a turma.')),
        );
        return;
      }

      // 1) valida nota (0..10)
      final value = num.tryParse(_notaCtrl.text.replaceAll(',', '.'));
      if (value == null || value < 0 || value > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe uma nota válida (0 a 10).')),
        );
        return;
      }

      // 2) RA obrigatório (podemos resolvê-lo via UID/Email)
      final ra = await _resolveRA();
      if (ra == null || ra.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe RA, UID ou E-mail do aluno para localizar o RA.')),
        );
        return;
      }

      // 3) (Opcional) checa matrícula: classes/{classId}/students/{ra}
      //    O professor dono da turma tem permissão de leitura, então podemos avisar antes de tentar gravar.
      final enrolled = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId.toString())
          .collection('students')
          .doc(ra)
          .get();

      if (!enrolled.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RA $ra não está matriculado na turma. Cadastre o aluno em classes/$classId/students/')),
        );
        return;
      }

      // 4) dados do professor
      final ownerUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // 5) usa ID previsível: activityId_RA (evita duplicar a mesma nota)
      final docId = '${activityId}_$ra';
      final ref = FirebaseFirestore.instance.collection('grades').doc(docId);

      await ref.set({
        // Vinculações fortes (casam com as rules)
        'activityRef': widget.activityRef, // DocumentReference
        'activityId': activityId,          // fallback/consulta
        'classId': classId,
        'studentRa': ra,

        // Campos opcionais (se quiser localizar também por uid/email)
        'studentUid': _uidCtrl.text.trim().isEmpty ? null : _uidCtrl.text.trim(),
        'studentEmail': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),

        // Dados da nota (salvamos 'value' e 'grade' para compatibilidade)
        'value': value,
        'grade': value,
        'ownerUid': ownerUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // Denormalizações (facilitam telas do aluno)
        'activityTitle': title,
        'activityWeight': weight,
        'className': className,
        'subject': subject,
      }, SetOptions(merge: true));

      _notaCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota lançada/atualizada.')),
      );
      FocusScope.of(context).unfocus();
    } on FirebaseException catch (e) {
      // Exibe erro das rules/índices de forma amigável
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao salvar nota: ${e.message ?? e.code}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          decoration: const InputDecoration(labelText: 'Nova nota (0–10)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) return;

    final v = num.tryParse(ctrl.text.replaceAll(',', '.'));
    if (v == null || v < 0 || v > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido. Informe 0 a 10.')),
      );
      return;
    }
    await ref.update({
      'value': v,
      'grade': v,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    final weight = (widget.activityData['weight'] ?? 1);
    final subject = (widget.activityData['subject'] ?? '').toString();
    final classNm = (widget.activityData['className'] ?? widget.activityData['classId'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Notas · $title'),
        actions: [
          if (subject.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Chip(label: Text(subject)),
            ),
          if (classNm.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Chip(label: Text(classNm)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
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
                      labelText: 'RA (obrigatório p/ salvar ou resolvido via UID/E-mail)',
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
                  onPressed: _saving ? null : _saveGrade,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
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
                    final value = (x['value'] ?? x['grade'] ?? 0);
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
                              onPressed: () => _editGrade(
                                d.reference,
                                value is num ? value : num.tryParse(value.toString()) ?? 0,
                              ),
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