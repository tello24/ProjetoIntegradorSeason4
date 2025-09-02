import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AlunoNotasPage extends StatefulWidget {
  const AlunoNotasPage({super.key});

  @override
  State<AlunoNotasPage> createState() => _AlunoNotasPageState();
}

class _AlunoNotasPageState extends State<AlunoNotasPage> {
  late final String _uid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _gradesStream;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      });
      return;
    }
    _uid = u.uid;

    _gradesStream = FirebaseFirestore.instance
        .collection('grades')
        .where('studentUid', isEqualTo: _uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas notas')),
      body: _gradesStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _gradesStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Erro: ${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('Você ainda não possui notas.'));
                }

                // Para média ponderada precisamos dos pesos das atividades.
                // Buscamos por activityId de cada nota.
                final grades = docs
                    .map((d) => d.data())
                    .map((m) => _Grade(
                          activityId: (m['activityId'] ?? '').toString(),
                          value: (m['value'] ?? 0) is num
                              ? (m['value'] as num).toDouble()
                              : double.tryParse(m['value'].toString()) ?? 0,
                        ))
                    .toList();

                return FutureBuilder<Map<String, double>>(
                  future: _fetchWeights(grades.map((g) => g.activityId).toSet()),
                  builder: (context, weightSnap) {
                    if (weightSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final weights = weightSnap.data ?? {};

                    double sumW = 0;
                    double sumWV = 0;

                    for (final g in grades) {
                      final w = weights[g.activityId] ?? 1.0;
                      sumW += w;
                      sumWV += w * g.value;
                    }
                    final media = sumW > 0 ? (sumWV / sumW) : 0.0;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: _MediaCard(media: media),
                        ),
                        const Divider(height: 0),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: grades.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final g = grades[i];
                              final w = weights[g.activityId] ?? 1.0;
                              return Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading:
                                      const Icon(Icons.assignment_turned_in),
                                  title: Text('Atividade: ${g.activityId}'),
                                  subtitle: Text('Nota: ${g.value} · Peso $w'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Future<Map<String, double>> _fetchWeights(Set<String> activityIds) async {
    if (activityIds.isEmpty) return {};
    final coll = FirebaseFirestore.instance.collection('activities');
    // Busca em blocos (simples; para poucas dezenas funciona bem).
    final Map<String, double> map = {};
    for (final id in activityIds) {
      final doc = await coll.doc(id).get();
      if (doc.exists) {
        final w = (doc.data()?['weight'] ?? 1) as num;
        map[id] = w.toDouble();
      }
    }
    return map;
  }
}

class _Grade {
  final String activityId;
  final double value;
  _Grade({required this.activityId, required this.value});
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.media});
  final double media;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.analytics_outlined, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Média ponderada',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Text(
              media.toStringAsFixed(2),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}