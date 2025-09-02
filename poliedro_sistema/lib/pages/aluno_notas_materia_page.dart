import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AlunoNotasMateriaPage extends StatefulWidget {
  final String ra;
  final String classId;
  final String className;
  const AlunoNotasMateriaPage({
    super.key,
    required this.ra,
    required this.classId,
    required this.className,
  });

  @override
  State<AlunoNotasMateriaPage> createState() => _AlunoNotasMateriaPageState();
}

class _AlunoNotasMateriaPageState extends State<AlunoNotasMateriaPage> {
  late Future<Set<String>> _activityIdsFuture;

  @override
  void initState() {
    super.initState();
    _activityIdsFuture = _loadActivityIdsForClass(widget.classId);
  }

  // Carrega IDs das atividades dessa turma (para filtrar notas mesmo que grade não tenha classId)
  Future<Set<String>> _loadActivityIdsForClass(String classId) async {
    // ⚠️ Requer que o aluno possa ler activities da sua turma (ver patch das rules abaixo).
    final s = await FirebaseFirestore.instance
        .collection('activities')
        .where('classId', isEqualTo: classId)
        .get();
    return s.docs.map((d) => d.id).toSet();
  }

  Stream<List<Map<String, dynamic>>> _gradesForRA(String ra) {
    return FirebaseFirestore.instance
        .collection('grades')
        .where('studentRa', isEqualTo: ra)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notas — ${widget.className}')),
      body: FutureBuilder<Set<String>>(
        future: _activityIdsFuture,
        builder: (context, futureSnap) {
          if (!futureSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final activityIds = futureSnap.data!;
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _gradesForRA(widget.ra),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final all = snap.data!;

              // Mantém notas: (grade.classId == turma) OU (grade.activityRef.id ∈ activities dessa turma)
              final filtered = all.where((g) {
                final classId = (g['classId'] ?? g['turmaId'])?.toString();
                if (classId == widget.classId) return true;

                final ref = g['activityRef'];
                if (ref is DocumentReference) return activityIds.contains(ref.id);

                final altId = (g['activityId'] ?? '').toString();
                return altId.isNotEmpty && activityIds.contains(altId);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('Sem notas lançadas para esta matéria.'));
              }

              // Média ponderada
              double somaPesos = 0, somaPontos = 0;
              for (final g in filtered) {
                final peso = (g['weight'] ?? g['activityWeight'] ?? 1).toDouble();
                final nota = (g['value'] ?? g['grade'] ?? 0).toDouble();
                somaPesos += peso;
                somaPontos += nota * peso;
              }
              final media = somaPesos > 0 ? somaPontos / somaPesos : 0;

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calculate),
                      title: const Text('Média ponderada'),
                      subtitle: const Text('Considerando os pesos das atividades'),
                      trailing: Text(
                        media.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...filtered.map((g) {
                    final titulo = (g['activityTitle'] ?? g['title'] ?? 'Atividade').toString();
                    final peso = (g['weight'] ?? g['activityWeight'] ?? 1).toDouble();
                    final nota = (g['value'] ?? g['grade'] ?? 0).toDouble();
                    final createdAt = (g['createdAt'] as Timestamp?)?.toDate();
                    return Card(
                      child: ListTile(
                        title: Text(titulo),
                        subtitle: Text('Peso: $peso'
                            '${createdAt != null ? ' · Lançada em ${_fmtDate(createdAt)}' : ''}'),
                        trailing: Text(nota.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}