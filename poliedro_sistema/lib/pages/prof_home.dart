import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Tela de turmas
import 'classes_page.dart';

class ProfHome extends StatefulWidget {
  const ProfHome({super.key});

  @override
  State<ProfHome> createState() => _ProfHomeState();
}

class _ProfHomeState extends State<ProfHome> {
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Sem sessão -> volta pro AuthGate/Login
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
    final email = user.email ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return _ErrorScaffold(
            message:
                'Perfil não encontrado no Firestore.\nCrie o registro em "users/$uid" ou refaça o cadastro.',
            onExit: _logout,
          );
        }

        final data = snap.data!.data()!;
        final role = (data['role'] ?? '').toString();
        final name = (data['name'] ?? '').toString();

        if (role != 'professor') {
          return _WrongRoleScaffold(
            expected: 'professor',
            actual: role,
            goTo: () => Navigator.pushNamedAndRemoveUntil(context, '/aluno', (_) => false),
            onExit: _logout,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Área do Professor'),
            actions: [
              IconButton(
                tooltip: 'Sair',
                onPressed: _logout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                // Cabeçalho
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      child: Text(
                        (name.isNotEmpty ? name[0] : 'P').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bem-vindo(a), ${name.isEmpty ? 'Professor' : name} 👋',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(email, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Chip(
                      avatar: Icon(Icons.school, size: 16),
                      label: Text('Professor'),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Turmas
                ListTile(
                  leading: const Icon(Icons.groups_2_outlined),
                  title: const Text('Turmas'),
                  subtitle: const Text('Gerencie turmas e alunos (por RA)'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ClassesPage()),
                    );
                  },
                ),

                // Materiais
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Materiais da disciplina'),
                  subtitle: const Text('Upload, links e compartilhamento por turma/RA'),
                  onTap: () => Navigator.pushNamed(context, '/materials'),
                ),

                // Futuro
                ListTile(
                  leading: const Icon(Icons.grade_outlined),
                  title: const Text('Notas'),
                  subtitle: const Text('CRUD de notas por aluno (em breve)'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.message_outlined),
                  title: const Text('Mensagens'),
                  subtitle: const Text('Contato individual com alunos (em breve)'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback onExit;
  const _ErrorScaffold({required this.message, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onExit,
              icon: const Icon(Icons.logout),
              label: const Text('Sair e voltar ao Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrongRoleScaffold extends StatelessWidget {
  final String expected;
  final String actual;
  final VoidCallback goTo;
  final VoidCallback onExit;

  const _WrongRoleScaffold({
    required this.expected,
    required this.actual,
    required this.goTo,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso restrito')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Este perfil não possui acesso à Área do $expected.\n'
              '(role atual: "$actual")',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: goTo,
              icon: const Icon(Icons.arrow_forward),
              label: Text('Ir para Área do ${expected == 'professor' ? 'Aluno' : 'Professor'}'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onExit,
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
            )
          ],
        ),
      ),
    );
  }
}
