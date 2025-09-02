import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/confirm_signout.dart';
import 'select_professor_page.dart'; // ← você já tinha
import 'select_class_for_grades_page.dart'; // ← NOVO

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
    if (uid == null) {
      _userFuture = Future.value(null);
    } else {
      _userFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .then((d) => d.data());
    }
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _ErrorScaffold(
            title: 'Área do Aluno',
            message: 'Erro: ${snap.error}',
          );
        }

        final data = snap.data;
        final user = FirebaseAuth.instance.currentUser;
        if (data == null || user == null) {
          return _ErrorScaffold(
            title: 'Área do Aluno',
            message: 'Perfil não encontrado no Firestore.\nFaça login novamente.',
          );
        }

        final role = (data['role'] ?? '').toString();
        final name = (data['name'] ?? 'Aluno').toString();
        final email = (user.email ?? '');

        if (role != 'aluno') {
          return _ErrorScaffold(
            title: 'Área do Aluno',
            message: 'Seu perfil não é "aluno". (Perfil atual: "${role.isEmpty ? '—' : role}")',
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Área do Aluno'),
            actions: [
              IconButton(
                tooltip: 'Sair',
                icon: const Icon(Icons.logout),
                onPressed: () => confirmSignOut(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(
                badgeIcon: Icons.school,
                badgeText: 'Aluno',
                name: name.isNotEmpty ? name : 'Aluno',
                email: email,
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Meus materiais',
                subtitle: 'Arquivos e links compartilhados com você',
                leading: const Icon(Icons.folder_copy_outlined),
                onTap: () => Navigator.pushNamed(context, '/materials'),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                title: 'Mensagens',
                subtitle: 'Conversar com professores',
                leading: const Icon(Icons.chat_bubble_outline),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectProfessorPage()),
                ),
              ),
              const SizedBox(height: 12),

              // ✅ NOVO: Notas por matéria (seleciona a turma e vê as notas dessa matéria)
              _SectionCard(
                title: 'Notas por matéria',
                subtitle: 'Veja suas notas por cada turma',
                leading: const Icon(Icons.fact_check_outlined),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectClassForGradesPage()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final IconData badgeIcon;
  final String badgeText;

  const _HeaderCard({
    required this.name,
    required this.email,
    required this.badgeIcon,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(email, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              avatar: Icon(badgeIcon, size: 16),
              label: Text(badgeText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget leading;
  final VoidCallback onTap;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String title;
  final String message;
  const _ErrorScaffold({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => confirmSignOut(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}