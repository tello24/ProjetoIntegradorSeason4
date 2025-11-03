// lib/pages/aluno_home.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/confirm_signout.dart';
import 'select_professor_page.dart';
import 'aluno_turmas_page.dart'; 
import 'aluno_notas_page.dart';

class AlunoHome extends StatefulWidget {
  const AlunoHome({super.key});
  @override
  State<AlunoHome> createState() => _AlunoHomeState();
}

class _AlunoHomeState extends State<AlunoHome> {
  Future<Map<String, dynamic>?>? _userFuture;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _userFuture = uid == null
        ? Future.value(null)
        : FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .then((d) => d.data());
  }

  @override
  Widget build(BuildContext context) {
    if (_userFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _userFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return const _ErrorScaffold(
            message: 'Erro ao carregar. Tente novamente.',
          );
        }

        final data = snap.data;
        final user = FirebaseAuth.instance.currentUser;
        if (data == null || user == null) {
          return const _ErrorScaffold(
            message:
                'Perfil não encontrado no Firestore.\nFaça login novamente.',
          );
        }

        final role = (data['role'] ?? '').toString();
        final name = (data['name'] ?? 'Aluno').toString();
        final email = (user.email ?? '').toString();

        if (role != 'aluno') {
          return _ErrorScaffold(
            message:
                'Seu perfil não é "aluno". (Perfil atual: "${role.isEmpty ? '—' : role}")',
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Sair',
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => confirmSignOut(context),
              ),
            ],
          ),
          extendBodyBehindAppBar: true,
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
              Center(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.12,
                    child: Image.asset(
                      'assets/images/iconePoliedro.png',
                      width: _watermarkSize(context),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          children: [
                            _Glass(
                              padding: const EdgeInsets.fromLTRB(
                                18, 14, 18, 14,
                              ),
                              radius: 18,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: const Color(0xFF3E5FBF),
                                    child: Text(
                                      (name.isNotEmpty
                                              ? name.characters.first
                                              : '?')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isNotEmpty ? name : 'Aluno',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.school,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Aluno',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: _HomeButton(
                                    label: 'Minhas Materias',
                                    icon: Icons.groups_2_outlined,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AlunoTurmasPage(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _HomeButton(
                                    label: 'Meus materiais',
                                    icon: Icons.folder_copy_outlined,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/materials',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _HomeButton(
                                    label: 'Mensagens',
                                    icon: Icons.chat_bubble_outline,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SelectProfessorPage(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _HomeButton(
                                    label: 'Minhas Notas',
                                    icon: Icons.bar_chart_rounded,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AlunoNotasPage(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _watermarkSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 640) {
      return (w * 1.15).clamp(420.0, 760.0);
    } else if (w < 1000) {
      return (w * 0.82).clamp(520.0, 780.0);
    } else {
      return (w * 0.55).clamp(700.0, 900.0);
    }
  }
}

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
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40), 
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)],
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => confirmSignOut(context),
          ),
        ],
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
          Center(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/images/iconePoliedro.png',
                  width: _watermarkSize(context),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: _Glass(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _watermarkSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 640) return (w * 2).clamp(420.0, 760.0);
    if (w < 1000) return (w * 0.82).clamp(520.0, 780.0);
    return (w * 0.55).clamp(700.0, 900.0);
  }
}