import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/confirm_signout.dart';
import 'classes_page.dart';
import 'materials_page.dart';
import 'select_student_page.dart';
import 'activities_page.dart'; // atalho para a sprint de Atividades & Notas

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

              // Painel rápido (atalhos principais)
              _QuickGrid(
                items: [
                  QuickItem(
                    icon: Icons.groups_2_outlined,
                    label: 'Minhas turmas',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ClassesPage()),
                    ),
                  ),
                  QuickItem(
                    icon: Icons.folder_copy_outlined,
                    label: 'Materiais',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MaterialsPage()),
                    ),
                  ),
                  QuickItem(
                    icon: Icons.calculate_outlined,
                    label: 'Atividades & Notas',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ActivitiesPage()),
                    ),
                  ),
                  QuickItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Mensagens',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SelectStudentPage()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Se preferir os cartões em lista (além do grid), mantive como no seu padrão:
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MaterialsPage()),
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                title: 'Atividades & Notas',
                subtitle: 'Cadastrar atividades com peso e lançar notas',
                leading: const Icon(Icons.calculate_outlined),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActivitiesPage()),
                ),
              ),
              const SizedBox(height: 12),

              // ✅ RESTAURADO: Mensagens (seleciona aluno e abre o Chat)
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

/// Grid de atalhos (bonitinho e prático pro topo)
class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.items});

  final List<QuickItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final count = w > 720 ? 4 : w > 520 ? 3 : 2;
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          mainAxisExtent: 96,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (_, i) {
          final it = items[i];
          return InkWell(
            onTap: it.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(it.icon, size: 26),
                    const SizedBox(height: 8),
                    Text(it.label, style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  QuickItem({required this.icon, required this.label, required this.onTap});
}