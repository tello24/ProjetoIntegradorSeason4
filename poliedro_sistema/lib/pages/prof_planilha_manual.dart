import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfPlanilhaManualPage extends StatefulWidget {
  const ProfPlanilhaManualPage({super.key});
  @override
  State<ProfPlanilhaManualPage> createState() => _ProfPlanilhaManualPageState();
}

class _ProfPlanilhaManualPageState extends State<ProfPlanilhaManualPage> with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? _selectedClassId;

  // cache
  List<_ClassLite> _classes = [];
  List<_Student> _students = [];                 // RA + Nome
  Map<String, _Entry> _entries = {};             // ra -> entry (b1..b4)
  bool _isSaving = false;

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this); // B1..B4
    _loadClasses();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // -------------------- Loads --------------------

  Future<void> _loadClasses() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final q = await _db.collection('classes')
        .where('ownerUid', isEqualTo: uid)
        .get();

    final list = <_ClassLite>[];
    for (final d in q.docs) {
      final data = d.data();
      final label = (data['name'] ?? data['title'] ?? data['materia'] ?? data['subject'] ?? d.id).toString();
      final rasDyn = (data['studentRAs'] as List?) ?? [];
      list.add(_ClassLite(
        id: d.id,
        label: label,
        studentRAs: rasDyn.map((e) => '$e').toList(),
      ));
    }

    setState(() {
      _classes = list;
      if (list.isNotEmpty) {
        _selectedClassId = list.first.id;
      }
    });

    if (_selectedClassId != null) {
      final cls = list.firstWhere((e) => e.id == _selectedClassId);
      await _loadStudentsForClass(cls.id, cls.studentRAs);
      await _loadEntries();
    }
  }

  Future<void> _loadStudentsForClass(String cid, List<String> rasFromArray) async {
    // 1) tenta subcoleção /classes/{cid}/students
    final sub = await _db.collection('classes').doc(cid).collection('students').get();
    final list = <_Student>[];

    if (sub.docs.isNotEmpty) {
      for (final d in sub.docs) {
        final data = d.data();
        final ra = d.id; // assumindo docId = RA
        final name = _pickName(data);
        list.add(_Student(ra: ra, name: name.isEmpty ? ra : name));
      }
    } else {
      // 2) fallback: usa array studentRAs e busca nomes em students_index/{ra}
      for (final ra in rasFromArray) {
        String nome = '';
        final idx = await _db.collection('students_index').doc(ra).get();
        if (idx.exists) {
          nome = _pickName(idx.data() ?? {});
        }
        list.add(_Student(ra: ra, name: nome.isEmpty ? ra : nome));
      }
    }

    // 3) fallback adicional: quem ainda ficou sem nome, tenta /users where ra == RA
    for (int i = 0; i < list.length; i++) {
      if (list[i].name == list[i].ra) {
        final ra = list[i].ra;
        final uq = await _db.collection('users').where('ra', isEqualTo: ra).limit(1).get();
        if (uq.docs.isNotEmpty) {
          final uname = _pickName(uq.docs.first.data());
          if (uname.isNotEmpty) {
            list[i] = _Student(ra: ra, name: uname);
          }
        }
      }
    }

    setState(() => _students = list..sort((a, b) => a.ra.compareTo(b.ra)));
  }

  String _pickName(Map<String, dynamic> data) {
    return (data['name'] ??
            data['nome'] ??
            data['displayName'] ??
            data['fullName'] ??
            data['studentName'] ??
            '')
        .toString();
  }

  Future<void> _loadEntries() async {
    if (_selectedClassId == null) {
      setState(() => _entries = {});
      return;
    }
    final uid = _auth.currentUser?.uid;
    final q = await _db
        .collection('grade_entries')
        .where('ownerUid', isEqualTo: uid)
        .where('classId', isEqualTo: _selectedClassId)
        .get();

    final map = <String, _Entry>{};
    for (final d in q.docs) {
      final data = d.data();
      final ra = (data['studentRa'] ?? '').toString();

      final scores = Map<String, dynamic>.from(data['scores'] ?? {});
      final b1 = Map<String, dynamic>.from(scores['b1'] ?? {});
      final b2 = Map<String, dynamic>.from(scores['b2'] ?? {});
      final b3 = Map<String, dynamic>.from(scores['b3'] ?? {});
      final b4 = Map<String, dynamic>.from(scores['b4'] ?? {});
      map[ra] = _Entry.fromDoc(
        id: d.id,
        ra: ra,
        b1: _Bim(
          a1: (b1['a1'] ?? 0) as num,
          a2: (b1['a2'] ?? 0) as num,
          a3: (b1['a3'] ?? 0) as num,
          prova: (b1['prova'] ?? 0) as num,
        ),
        b2: _Bim(
          a1: (b2['a1'] ?? 0) as num,
          a2: (b2['a2'] ?? 0) as num,
          a3: (b2['a3'] ?? 0) as num,
          prova: (b2['prova'] ?? 0) as num,
        ),
        b3: _Bim(
          a1: (b3['a1'] ?? 0) as num,
          a2: (b3['a2'] ?? 0) as num,
          a3: (b3['a3'] ?? 0) as num,
          prova: (b3['prova'] ?? 0) as num,
        ),
        b4: _Bim(
          a1: (b4['a1'] ?? 0) as num,
          a2: (b4['a2'] ?? 0) as num,
          a3: (b4['a3'] ?? 0) as num,
          prova: (b4['prova'] ?? 0) as num,
        ),
      );
    }

    setState(() => _entries = map);
  }

  // -------------------- Save (manual) --------------------

  Future<void> _saveAll() async {
    if (_selectedClassId == null) return;

    setState(() => _isSaving = true);
    final uid = _auth.currentUser?.uid;
    final batch = _db.batch();

    for (final st in _students) {
      final ra = st.ra;
      final e = _entries.putIfAbsent(ra, () => _Entry.empty(ra));

      final payload = {
        'ownerUid': uid,
        'classId': _selectedClassId,
        'studentRa': ra,
        'scores': {
          'b1': {'a1': e.b1.a1, 'a2': e.b1.a2, 'a3': e.b1.a3, 'prova': e.b1.prova},
          'b2': {'a1': e.b2.a1, 'a2': e.b2.a2, 'a3': e.b2.a3, 'prova': e.b2.prova},
          'b3': {'a1': e.b3.a1, 'a2': e.b3.a2, 'a3': e.b3.a3, 'prova': e.b3.prova},
          'b4': {'a1': e.b4.a1, 'a2': e.b4.a2, 'a3': e.b4.a3, 'prova': e.b4.prova},
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (e.id == null) {
        final ref = _db.collection('grade_entries').doc();
        batch.set(ref, {
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _entries[ra] = e.copyWith(id: ref.id);
      } else {
        final ref = _db.collection('grade_entries').doc(e.id);
        batch.update(ref, payload);
      }
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notas salvas com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // -------------------- Helpers (REGRAS DE ARREDONDAMENTO) --------------------

  // média bruta do bimestre (0..10)
  num _avgBimRaw(_Bim b) => (b.a1 + b.a2 + b.a3 + b.prova) / 4;

  // aplica a tua regra customizada
  num _customRound(num v) {
    final base = v.floor();
    final frac = v - base;
    if (frac < 0.35) return base;             // < .35 => inteiro
    if (frac < 0.50) return base + 0.5;       // [.35, .50) => .5
    if (frac < 0.75) return double.parse(v.toStringAsFixed(2)); // [.50, .75) => mantém
    return base + 1;                           // >= .75 => próximo inteiro
  }

  // média do bimestre (aplica regra)
  num _avgBim(_Bim b) => _customRound(_avgBimRaw(b));

  // média final (média aritmética dos 4 bimestres BRUTOS, depois aplica regra)
  num _finalOf(String ra) {
    final e = _entries[ra];
    if (e == null) return 0;
    final mb1 = _avgBimRaw(e.b1);
    final mb2 = _avgBimRaw(e.b2);
    final mb3 = _avgBimRaw(e.b3);
    final mb4 = _avgBimRaw(e.b4);
    final mfRaw = (mb1 + mb2 + mb3 + mb4) / 4;
    return _customRound(mfRaw);
  }

  String _fmt(num v) {
    // mostra sem casas se inteiro, 1 casa se x.0, senão 2 casas
    if (v % 1 == 0) return v.toStringAsFixed(0);
    final s2 = v.toStringAsFixed(2);
    if (s2.endsWith('0')) return v.toStringAsFixed(1);
    return s2;
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planilha manual (Bimestres)'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: _isSaving || _selectedClassId == null ? null : _saveAll,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Salvando...' : 'Salvar alterações'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildTopBar(),
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
                  _buildTable(bim: 1),
                  _buildTable(bim: 2),
                  _buildTable(bim: 3),
                  _buildTable(bim: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
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
              setState(() {
                _selectedClassId = v;
                _entries = {};
              });
              final cls = _classes.firstWhere((e) => e.id == v);
              await _loadStudentsForClass(cls.id, cls.studentRAs);
              await _loadEntries();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTable({required int bim}) {
    if (_selectedClassId == null) {
      return const Center(child: Text('Selecione uma turma'));
    }

    final cols = const [
      DataColumn(label: Text('RA')),
      DataColumn(label: Text('Nome')),
      DataColumn(label: Text('Ativ. 1')),
      DataColumn(label: Text('Ativ. 2')),
      DataColumn(label: Text('Ativ. 3')),
      DataColumn(label: Text('Prova')),
      DataColumn(label: Text('Média do Bim.')),
      DataColumn(label: Text('Média Final')),
    ];

    final rows = _students.map((st) {
      final ra = st.ra;
      final e = _entries.putIfAbsent(ra, () => _Entry.empty(ra));
      final b = switch (bim) { 1 => e.b1, 2 => e.b2, 3 => e.b3, _ => e.b4 };

      return DataRow(cells: [
        DataCell(Text(ra)),
        DataCell(Text(st.name)),
        DataCell(_NumCell(
          value: b.a1,
          onChanged: (n) {
            final nb = b.copyWith(a1: n);
            _entries[ra] = switch (bim) {
              1 => e.copyWith(b1: nb),
              2 => e.copyWith(b2: nb),
              3 => e.copyWith(b3: nb),
              _ => e.copyWith(b4: nb),
            };
            setState(() {});
          },
        )),
        DataCell(_NumCell(
          value: b.a2,
          onChanged: (n) {
            final nb = b.copyWith(a2: n);
            _entries[ra] = switch (bim) {
              1 => e.copyWith(b1: nb),
              2 => e.copyWith(b2: nb),
              3 => e.copyWith(b3: nb),
              _ => e.copyWith(b4: nb),
            };
            setState(() {});
          },
        )),
        DataCell(_NumCell(
          value: b.a3,
          onChanged: (n) {
            final nb = b.copyWith(a3: n);
            _entries[ra] = switch (bim) {
              1 => e.copyWith(b1: nb),
              2 => e.copyWith(b2: nb),
              3 => e.copyWith(b3: nb),
              _ => e.copyWith(b4: nb),
            };
            setState(() {});
          },
        )),
        DataCell(_NumCell(
          value: b.prova,
          onChanged: (n) {
            final nb = b.copyWith(prova: n);
            _entries[ra] = switch (bim) {
              1 => e.copyWith(b1: nb),
              2 => e.copyWith(b2: nb),
              3 => e.copyWith(b3: nb),
              _ => e.copyWith(b4: nb),
            };
            setState(() {});
          },
        )),
        DataCell(Text(_fmt(_avgBim(b)))),      // média do bimestre com regra
        DataCell(Text(_fmt(_finalOf(ra)))),    // média final com regra
      ]);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Dica: edite os valores e clique em "Salvar alterações" para gravar no Firestore.'),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(columns: cols, rows: rows),
          ),
        ),
      ],
    );
  }
}

/* ====== modelos simples ====== */
class _ClassLite {
  final String id;
  final String label;
  final List<String> studentRAs;
  _ClassLite({required this.id, required this.label, required this.studentRAs});
}

class _Student {
  final String ra;
  final String name;
  _Student({required this.ra, required this.name});
}

class _Bim {
  final num a1, a2, a3, prova;
  _Bim({required this.a1, required this.a2, required this.a3, required this.prova});

  _Bim copyWith({num? a1, num? a2, num? a3, num? prova}) =>
      _Bim(a1: a1 ?? this.a1, a2: a2 ?? this.a2, a3: a3 ?? this.a3, prova: prova ?? this.prova);
}

class _Entry {
  final String? id;
  final String ra;
  final _Bim b1;
  final _Bim b2;
  final _Bim b3;
  final _Bim b4;

  _Entry({required this.id, required this.ra, required this.b1, required this.b2, required this.b3, required this.b4});

  factory _Entry.empty(String ra) => _Entry(
    id: null,
    ra: ra,
    b1: _Bim(a1: 0, a2: 0, a3: 0, prova: 0),
    b2: _Bim(a1: 0, a2: 0, a3: 0, prova: 0),
    b3: _Bim(a1: 0, a2: 0, a3: 0, prova: 0),
    b4: _Bim(a1: 0, a2: 0, a3: 0, prova: 0),
  );

  factory _Entry.fromDoc({
    required String id,
    required String ra,
    required _Bim b1,
    required _Bim b2,
    required _Bim b3,
    required _Bim b4,
  }) => _Entry(id: id, ra: ra, b1: b1, b2: b2, b3: b3, b4: b4);

  _Entry copyWith({String? id, _Bim? b1, _Bim? b2, _Bim? b3, _Bim? b4}) {
    return _Entry(
      id: id ?? this.id,
      ra: ra,
      b1: b1 ?? this.b1,
      b2: b2 ?? this.b2,
      b3: b3 ?? this.b3,
      b4: b4 ?? this.b4,
    );
  }
}

/* ===== Campo numérico "estável" para não perder cursor ===== */
class _NumCell extends StatefulWidget {
  final num value;
  final ValueChanged<num> onChanged;
  const _NumCell({required this.value, required this.onChanged, super.key});

  @override
  State<_NumCell> createState() => _NumCellState();
}

class _NumCellState extends State<_NumCell> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _NumCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _c.text != widget.value.toString()) {
      _c.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: _c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        onChanged: (txt) {
          final n = num.tryParse(txt.replaceAll(',', '.'));
          if (n == null || n < 0 || n > 10) return;
          widget.onChanged(n);
        },
      ),
    );
  }
}
