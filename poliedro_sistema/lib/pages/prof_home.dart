import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfHome extends StatefulWidget {
  const ProfHome({super.key});

  @override
  State<ProfHome> createState() => _ProfHomeState();
}

class _ProfHomeState extends State<ProfHome> {
  Future<Map<String, dynamic>?>? _userFuture;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Se não houver sessão, volta ao login após o primeiro frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      });
    } else {
      _userFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .then((d) => d.data());
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
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

        final data = snap.data;
        if (data == null) {
          return _ErrorScaffold(
            onExit: _logout,
            message:
                'Perfil não encontrado no Firestore.\nCrie o registro em "users/{uid}" ou refaça o cadastro.',
          );
        }

        final role = (data['role'] ?? '').toString();
        final name = (data['name'] ?? '').toString();
        final email = (FirebaseAuth.instance.currentUser?.email ?? '');

        // Sem redirecionar automaticamente no build — exibimos um aviso elegante
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
              IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Sair'),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text('Bem-vindo(a), ${name.isEmpty ? 'Professor' : name} 👋',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(email),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Materiais da disciplina'),
                  subtitle: const Text('Upload e organização (em breve)'),
                  onTap: () {},
                ),
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
