import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'chat_page.dart';

class SelectProfessorPage extends StatefulWidget {
  const SelectProfessorPage({super.key});

  @override
  State<SelectProfessorPage> createState() => _SelectProfessorPageState();
}

class _SelectProfessorPageState extends State<SelectProfessorPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'professor');

    return Scaffold(
      appBar: AppBar(title: const Text("Selecionar professor")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Buscar por nome ou email...",
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text("Erro: ${snap.error}"));
                }

                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  final email = (d['email'] ?? '').toString().toLowerCase();
                  return _query.isEmpty ||
                      name.contains(_query) ||
                      email.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("Nenhum professor encontrado"));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final uid = d.id;
                    final name = (d['name'] ?? 'Professor').toString();
                    final email = (d['email'] ?? '').toString();

                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.school)),
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              peerUid: uid,
                              peerName: name,
                              peerEmail: email,
                              peerRa: null,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}