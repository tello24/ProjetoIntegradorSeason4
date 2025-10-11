// lib/pages/alunos_da_turma_page.dart
// CÓDIGO FINAL CORRIGIDO

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AlunosDaTurmaPage extends StatefulWidget {
  final String turmaId;
  final String nomeTurma;

  const AlunosDaTurmaPage({
    super.key,
    required this.turmaId,
    required this.nomeTurma,
  });

  @override
  State<AlunosDaTurmaPage> createState() => _AlunosDaTurmaPageState();
}

class _AlunosDaTurmaPageState extends State<AlunosDaTurmaPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _alunos = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchAlunos();
  }

  Future<void> _fetchAlunos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final studentDocs = await _firestore
          .collection('classes')
          .doc(widget.turmaId)
          .collection('students')
          .get();

      final ras = studentDocs.docs.map((doc) => doc.id).toList();
      if (ras.isEmpty) {
        if (mounted) setState(() => _alunos = []);
        return;
      }

      final usersQuery = await _firestore
          .collection('users')
          .where('ra', whereIn: ras)
          .get();

      final alunosData = usersQuery.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id; // Adiciona o UID para uso posterior
        return data;
      }).toList();

      if (mounted) setState(() => _alunos = alunosData);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar alunos: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MODIFICAÇÃO: 'batch write' simplificado ---
  Future<void> _addStudentByRa(String ra) async {
    final raTrimmed = ra.trim();
    if (!RegExp(r'^\d{7}$').hasMatch(raTrimmed)) {
      _showErrorSnackBar('RA inválido. Informe exatamente 7 dígitos numéricos.');
      return;
    }
    if (_alunos.any((aluno) => aluno['ra'] == raTrimmed)) {
      _showErrorSnackBar('Este aluno já está cadastrado na turma.');
      return;
    }

    try {
      final userQuery = await _firestore
          .collection('users')
          .where('ra', isEqualTo: raTrimmed)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showErrorSnackBar('Nenhum aluno encontrado com o RA informado.');
        return;
      }
      
      final batch = _firestore.batch();
      final classRef = _firestore.collection('classes').doc(widget.turmaId);

      // 1. Adiciona na subcoleção da turma
      batch.set(classRef.collection('students').doc(raTrimmed), {
        'addedAt': FieldValue.serverTimestamp(),
        'ra': raTrimmed,
      });
      // 2. Adiciona no array studentRAs da turma
      batch.update(classRef, {
        'studentRAs': FieldValue.arrayUnion([raTrimmed]),
      });

      await batch.commit();

      Navigator.of(context).pop();
      _showSuccessSnackBar('Aluno adicionado com sucesso!');
      await _fetchAlunos();
    } on FirebaseException catch (e) {
      _showErrorSnackBar('Erro de banco de dados: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Ocorreu um erro inesperado: $e');
    }
  }
  
  // --- MODIFICAÇÃO: 'batch write' simplificado ---
  Future<void> _deleteStudent(String ra) async {
    try {
      final batch = _firestore.batch();
      final classRef = _firestore.collection('classes').doc(widget.turmaId);

      // 1. Remove da subcoleção da turma
      batch.delete(classRef.collection('students').doc(ra));
      // 2. Remove do array studentRAs da turma
      batch.update(classRef, {
        'studentRAs': FieldValue.arrayRemove([ra]),
      });

      await batch.commit();

      setState(() {
        _alunos.removeWhere((aluno) => aluno['ra'] == ra);
      });
      _showSuccessSnackBar('Aluno removido da turma.');
    } on FirebaseException catch (e) {
      _showErrorSnackBar('Erro de banco de dados: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Ocorreu um erro inesperado ao remover: $e');
    }
  }

  void _showAddStudentDialog() {
    final raController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adicionar Aluno por RA'),
          content: TextField(
            controller: raController,
            decoration: const InputDecoration(labelText: 'RA do Aluno (7 dígitos)'),
            keyboardType: TextInputType.number,
            maxLength: 7,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => _addStudentByRa(raController.text),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Alunos de ${widget.nomeTurma}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Aluno'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Bg(),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _alunos.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum aluno cadastrado nesta turma.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, kToolbarHeight, 12, 16),
                        itemCount: _alunos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final aluno = _alunos[index];
                          return _Glass(
                            radius: 16,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueGrey[700],
                                child: Text(
                                  aluno['name']?.substring(0, 1) ?? 'A',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                aluno['name'] ?? 'Nome não encontrado',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'RA: ${aluno['ra'] ?? 'N/A'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: 'Remover aluno da turma',
                                onPressed: () => _deleteStudent(aluno['ra']),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ----- Widgets de UI (copiados para manter consistência) -----
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