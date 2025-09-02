import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'aluno_notas_materia_page.dart';

class SelectClassForGradesPage extends StatefulWidget {
  const SelectClassForGradesPage({super.key});

  @override
  State<SelectClassForGradesPage> createState() => _SelectClassForGradesPageState();
}

class _SelectClassForGradesPageState extends State<SelectClassForGradesPage> {
  String? _ra;

  @override
  void initState() {
    super.initState();
    _loadRA();
  }

  Future<void> _loadRA() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final me = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() => _ra = me.data()?['ra']?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_ra == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Selecione a matéria')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_ra!.isEmpty) {
      return const _ScaffoldBase(
        title: 'Selecione a matéria',
        body: _StateCard(
          icon: Icons.perm_identity,
          title: 'RA não cadastrado',
          subtitle: 'Peça para o professor atualizar seu RA no cadastro.',
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('classes')
        .where('studentRAs', arrayContains: _ra) // << chave do sucesso
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _ScaffoldBase(
            title: 'Selecione a matéria',
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _ScaffoldBase(
            title: 'Selecione a matéria',
            body: _StateCard(
              icon: Icons.error_outline,
              title: 'Erro ao carregar turmas',
              subtitle: '${snap.error}',
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _ScaffoldBase(
            title: 'Selecione a matéria',
            body: _StateCard(
              icon: Icons.bookmark_border,
              title: 'Você ainda não está matriculado em turmas',
              subtitle: 'Quando for vinculado, elas aparecerão aqui.',
            ),
          );
        }

        return _ScaffoldBase(
          title: 'Selecione a matéria',
          body: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i];
              final cid = d.id;
              final name = (d.data()['name'] ?? cid).toString();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.class_),
                  title: Text(name),
                  subtitle: Text('ID: $cid'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlunoNotasMateriaPage(
                          ra: _ra!,
                          classId: cid,
                          className: name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ======== UI helpers ========

class _ScaffoldBase extends StatelessWidget {
  final String title;
  final Widget body;
  const _ScaffoldBase({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _StateCard({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}