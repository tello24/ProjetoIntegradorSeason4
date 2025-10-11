// lib/pages/aluno_turmas_page.dart
// CÓDIGO CORRIGIDO

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'aluno_detalhes_turma_page.dart';

class AlunoTurmasPage extends StatefulWidget {
  const AlunoTurmasPage({super.key});

  @override
  State<AlunoTurmasPage> createState() => _AlunoTurmasPageState();
}

class _AlunoTurmasPageState extends State<AlunoTurmasPage> {
  String? _studentRa;
  bool _isLoadingRa = true;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _turmasStream;

  @override
  void initState() {
    super.initState();
    _setupStreamBasedOnRa();
  }

  Future<void> _setupStreamBasedOnRa() async {
    if (!mounted) return;
    setState(() => _isLoadingRa = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final ra = userDoc.data()?['ra']?.toString();

      if (ra != null && ra.isNotEmpty) {
        _studentRa = ra;
        // MODIFICAÇÃO PRINCIPAL: A consulta agora busca na coleção 'classes'
        // onde o RA do aluno está no array 'studentRAs'.
        _turmasStream = FirebaseFirestore.instance
            .collection('classes')
            .where('studentRAs', arrayContains: _studentRa)
            .snapshots();
      } else {
        _turmasStream = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar RA: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRa = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Minhas Turmas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Bg(),
          SafeArea(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingRa) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_studentRa == null || _studentRa!.isEmpty || _turmasStream == null) {
      return const Center(
        child: Text(
          'Seu RA não foi encontrado.\nVocê não está matriculado em nenhuma turma.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _turmasStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Erro ao carregar turmas: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final turmas = snapshot.data?.docs ?? [];

        if (turmas.isEmpty) {
          return const Center(
            child: Text(
              'Você não está matriculado em nenhuma turma.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, kToolbarHeight / 2, 12, 16),
          itemCount: turmas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final turmaDoc = turmas[index];
            final turmaData = turmaDoc.data();
            final nomeTurma = (turmaData['name'] ?? 'Turma sem nome').toString();

            return _Glass(
              radius: 16,
              child: ListTile(
                leading: const Icon(Icons.school_outlined, color: Colors.white),
                title: Text(
                  nomeTurma,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Professor: ${turmaData['ownerEmail'] ?? 'Não informado'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlunoDetalhesTurmaPage(
                        turmaId: turmaDoc.id,
                        nomeTurma: nomeTurma,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
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

class _Bg extends StatelessWidget {
  const _Bg();
  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}