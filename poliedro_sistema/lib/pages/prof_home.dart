import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/confirm_signout.dart';
import 'classes_page.dart';
import 'select_student_page.dart'; // ← novo: abre seleção de aluno

class ProfHome extends StatefulWidget {
  const ProfHome({super.key});
  @override
  State<ProfHome> createState() => _ProfHomeState();
}

class _ProfHomeState extends State<ProfHome> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Área do Professor')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
            icon: const Icon(Icons.login),
            label: const Text('Fazer login'),
          ),
        ),
      );
    }

    final uid = user.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _ErrorScaffold(
            title: 'Área do Professor',
            message: 'Erro: ${snap.error}',
          );
        }

        final data = snap.data?.data();
        if (data == null) {
          return _ErrorScaffold(
            title: 'Área do Professor',
            message: 'Perfil não encontrado no Firestore.\nCrie o registro em "users/$uid" ou refaça o cadastro.',
          );
        }

        final role = (data['role'] ?? '').toString();
        final name = (data['name'] ?? '').toString();
        final email = (user.email ?? '');

        if (role != 'professor') {
          return _ErrorScaffold(
            title: 'Área do Professor',
            message: 'Seu perfil não é "professor". (Perfil atual: "${role.isEmpty ? '—' : role}")',
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Área do Professor'),
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
                badgeText: 'Professor',
                name: name.isEmpty ? 'Professor' : name,
                email: email,
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Minhas turmas',
                subtitle: 'Gerenciar turmas e RAs',
                leading: const Icon(Icons.groups_2_outlined),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClassesPage()),
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                title: 'Materiais',
                subtitle: 'Enviar links/arquivos e compartilhar com turmas',
                leading: const Icon(Icons.folder_copy_outlined),
                onTap: () => Navigator.pushNamed(context, '/materials'),
              ),
              const SizedBox(height: 12),

              // NOVO: Mensagens → Selecionar Aluno
              _SectionCard(
                title: 'Mensagens',
                subtitle: 'Conversar com um aluno',
                leading: const Icon(Icons.chat_bubble_outline),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectStudentPage()),
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
                  Text(name.isNotEmpty ? name : 'Professor', style: Theme.of(context).textTheme.titleMedium),
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
  _ErrorScaffold({required this.title, required this.message}); // sem const p/ hot reload suave

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