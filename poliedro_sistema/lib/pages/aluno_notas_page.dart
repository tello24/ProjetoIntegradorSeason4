import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AlunoNotasPage extends StatefulWidget {
  const AlunoNotasPage({super.key});
  @override
  State<AlunoNotasPage> createState() => _AlunoNotasPageState();
}

class _AlunoNotasPageState extends State<AlunoNotasPage> with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? _selectedClassId;
  String _myRA = '';

  List<_ClassLite> _classes = [];
  _EntryView? _entry; // só leitura
  bool _loading = true;

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this); // 4 bimestres
    _boot();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    // pega RA do aluno
    final me = await _db.collection('users').doc(uid).get();
    _myRA = (me.data()?['ra'] ?? '').toString();

    // carrega turmas nas quais o RA aparece
    final q = await _db.collection('classes')
      .where('studentRAs', arrayContains: _myRA)
      .get();

    final list = <_ClassLite>[];
    for (final d in q.docs) {
      final data = d.data();
      final label = (data['name'] ?? data['title'] ?? data['materia'] ?? data['subject'] ?? d.id).toString();
      list.add(_ClassLite(id: d.id, label: label));
    }

    setState(() {
      _classes = list;
      _selectedClassId = list.isNotEmpty ? list.first.id : null;
    });

    await _loadEntry();
    setState(() => _loading = false);
  }

  Future<void> _loadEntry() async {
    _entry = null;
    if (_selectedClassId == null || _myRA.isEmpty) {
      setState(() {});
      return;
    }

    // Leitura por turma + RA
    final q = await _db.collection('grade_entries')
      .where('classId', isEqualTo: _selectedClassId)
      .where('studentRa', isEqualTo: _myRA)
      .limit(1)
      .get();

    if (q.docs.isEmpty) {
      setState(() => _entry = _EntryView.empty());
      return;
    }

    final d = q.docs.first;
    final data = d.data();
    final scores = Map<String, dynamic>.from(data['scores'] ?? {});
    _entry = _EntryView.fromScores(scores);
    setState(() {});
  }

  // -------- Regras de arredondamento (iguais à tela do Professor) --------

  // média bruta do bimestre (0..10)
  num _avgBimRaw(_Bim b) => (b.a1 + b.a2 + b.a3 + b.prova) / 4;

  // aplica tua regra customizada
  num _customRound(num v) {
    final base = v.floor();
    final frac = v - base;
    if (frac < 0.35) return base;                  // < .35 => inteiro
    if (frac < 0.50) return base + 0.5;            // [.35, .50) => .5
    if (frac < 0.75) return double.parse(v.toStringAsFixed(2)); // [.50, .75) => mantém
    return base + 1;                                // >= .75 => próximo inteiro
  }

  num _avgBim(_Bim b) => _customRound(_avgBimRaw(b));

  // média final = média das brutas dos 4 bimestres, depois aplica regra
  num _finalRounded(_EntryView e) {
    final mfRaw = (_avgBimRaw(e.b1) + _avgBimRaw(e.b2) + _avgBimRaw(e.b3) + _avgBimRaw(e.b4)) / 4;
    return _customRound(mfRaw);
  }

  String _fmt(num v) {
    // mostra sem casas se inteiro, 1 casa se x.0, senão 2 casas
    if (v % 1 == 0) return v.toStringAsFixed(0);
    final s2 = v.toStringAsFixed(2);
    if (s2.endsWith('0')) return v.toStringAsFixed(1);
    return s2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Notas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedClassId,
                          items: _classes
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.label)))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Turma',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) async {
                            setState(() => _selectedClassId = v);
                            await _loadEntry();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TabBar(
                    controller: _tab,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                    tabs: const [
                      Tab(text: 'Bimestre 1'),
                      Tab(text: 'Bimestre 2'),
                      Tab(text: 'Bimestre 3'),
                      Tab(text: 'Bimestre 4'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        _buildBim(bim: 1),
                        _buildBim(bim: 2),
                        _buildBim(bim: 3),
                        _buildBim(bim: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBim({required int bim}) {
    final e = _entry ?? _EntryView.empty();
    final b = switch (bim) { 1 => e.b1, 2 => e.b2, 3 => e.b3, _ => e.b4 };
    final mbRounded = _avgBim(b);
    final mfRounded = _finalRounded(e);

    final cells = [
      // Notas das avaliações: exibimos brutas (duas casas)
      _kv('Ativ. 1', double.parse(b.a1.toStringAsFixed(2))),
      _kv('Ativ. 2', double.parse(b.a2.toStringAsFixed(2))),
      _kv('Ativ. 3', double.parse(b.a3.toStringAsFixed(2))),
      _kv('Prova', double.parse(b.prova.toStringAsFixed(2))),
      // Médias com a regra
      _kv('Média do Bimestre', mbRounded),
      _kv('Média Final', mfRounded),
    ];

    return ListView.separated(
      itemCount: cells.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => Card(
        child: ListTile(
          title: Text(cells[i].$1),
          trailing: Text(
            _fmt(cells[i].$2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  (String, num) _kv(String k, num v) => (k, v);
}

/* ===== modelos simples ===== */
class _ClassLite {
  final String id;
  final String label;
  _ClassLite({required this.id, required this.label});
}

class _Bim {
  final num a1, a2, a3, prova;
  _Bim({required this.a1, required this.a2, required this.a3, required this.prova});
  factory _Bim.fromMap(Map<String, dynamic> m) => _Bim(
    a1: (m['a1'] ?? 0) as num,
    a2: (m['a2'] ?? 0) as num,
    a3: (m['a3'] ?? 0) as num,
    prova: (m['prova'] ?? 0) as num,
  );
  static _Bim zero() => _Bim(a1: 0, a2: 0, a3: 0, prova: 0);
}

class _EntryView {
  final _Bim b1, b2, b3, b4;
  _EntryView({required this.b1, required this.b2, required this.b3, required this.b4});
  factory _EntryView.fromScores(Map<String, dynamic> scores) => _EntryView(
    b1: _Bim.fromMap(Map<String, dynamic>.from(scores['b1'] ?? {})),
    b2: _Bim.fromMap(Map<String, dynamic>.from(scores['b2'] ?? {})),
    b3: _Bim.fromMap(Map<String, dynamic>.from(scores['b3'] ?? {})),
    b4: _Bim.fromMap(Map<String, dynamic>.from(scores['b4'] ?? {})),
  );
  factory _EntryView.empty() => _EntryView(b1: _Bim.zero(), b2: _Bim.zero(), b3: _Bim.zero(), b4: _Bim.zero());
}
