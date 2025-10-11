// lib/pages/gerenciamento_turma_page.dart
// CÓDIGO CORRIGIDO

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import necessário
import 'alunos_da_turma_page.dart';
import 'materiais_da_turma_page.dart';

class GerenciamentoTurmaPage extends StatefulWidget {
  final String turmaId;
  final String nomeTurma;

  const GerenciamentoTurmaPage({
    super.key,
    required this.turmaId,
    required this.nomeTurma,
  });

  @override
  State<GerenciamentoTurmaPage> createState() => _GerenciamentoTurmaPageState();
}

class _GerenciamentoTurmaPageState extends State<GerenciamentoTurmaPage> {
  int? _studentCount;
  int? _materialCount;
  bool _isLoadingSummary = true;
  late final String _uid; // UID do professor logado

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid; // Pega o UID do professor
    _fetchSummaryData();
  }

  Future<void> _fetchSummaryData() async {
    try {
      final studentSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.turmaId)
          .collection('students')
          .count()
          .get();

      // CORREÇÃO APLICADA AQUI:
      // A consulta de contagem de materiais agora também filtra pelo UID do professor,
      // assim como fizemos na página de listagem de materiais, para cumprir a regra de segurança.
      final materialSnapshot = await FirebaseFirestore.instance
          .collection('materials')
          .where('classIds', arrayContains: widget.turmaId)
          .where(
            'ownerUid',
            isEqualTo: _uid,
          ) // <-- LINHA ADICIONADA QUE CORRIGE O PROBLEMA
          .count()
          .get();

      if (mounted) {
        setState(() {
          _studentCount = studentSnapshot.count;
          _materialCount = materialSnapshot.count;
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      print(
        "Erro ao buscar resumo: $e",
      ); // Adicionado um print para ajudar a depurar
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          _studentCount = 0;
          _materialCount = 0;
        });
      }
    }
  }

  Widget _buildSummaryCard() {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Painel de Controle',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.nomeTurma,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white24, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.groups_2_outlined,
                label: 'Alunos',
                value: _studentCount,
              ),
              _buildSummaryItem(
                icon: Icons.folder_copy_outlined,
                label: 'Materiais',
                value: _materialCount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    int? value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 8),
        _isLoadingSummary
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                value?.toString() ?? '0',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.nomeTurma,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
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
                  const Color(0xFF0B091B).withOpacity(.92),
                  const Color(0xFF0B091B).withOpacity(.92),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight),
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  _ActionCard(
                    icon: Icons.groups_2_outlined,
                    title: 'Alunos Cadastrados',
                    subtitle: 'Visualizar lista e gerenciar RAs da turma',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlunosDaTurmaPage(
                            turmaId: widget.turmaId,
                            nomeTurma: widget.nomeTurma,
                          ),
                        ),
                      ).then((_) => _fetchSummaryData());
                    },
                  ),
                  const SizedBox(height: 16),
                  _ActionCard(
                    icon: Icons.folder_copy_outlined,
                    title: 'Materiais da Turma',
                    subtitle: 'Visualizar e enviar links ou arquivos',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MateriaisDaTurmaPage(
                            turmaId: widget.turmaId,
                            nomeTurma: widget.nomeTurma,
                          ),
                        ),
                      ).then((_) => _fetchSummaryData());
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ========================= UI Helpers (mantidos como estavam) ========================= */
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const _Glass({required this.child, this.padding, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121022).withOpacity(.18),
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
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
