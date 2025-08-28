import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'chat_page.dart';

class SelectStudentPage extends StatefulWidget {
  const SelectStudentPage({super.key});

  @override
  State<SelectStudentPage> createState() => _SelectStudentPageState();
}

class _SelectStudentPageState extends State<SelectStudentPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'aluno');

    return Scaffold(
      appBar: AppBar(title: const Text("Selecionar aluno")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Buscar por nome ou RA...",
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
                  final ra = (d['ra'] ?? '').toString();
                  return _query.isEmpty ||
                      name.contains(_query) ||
                      ra.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("Nenhum aluno encontrado"));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final uid = d.id;
                    final name = (d['name'] ?? 'Aluno').toString();
                    final ra = (d['ra'] ?? '').toString();

                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text("$name · RA $ra"),
                      subtitle: Text("ID: $uid"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              peerUid: uid,
                              peerName: name,
                              peerEmail: d['email'],
                              peerRa: ra,
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