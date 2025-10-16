import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfPlanilhaManualPage extends StatefulWidget {
  const ProfPlanilhaManualPage({super.key});
  @override
  State<ProfPlanilhaManualPage> createState() => _ProfPlanilhaManualPageState();
}

class _ProfPlanilhaManualPageState extends State<ProfPlanilhaManualPage>
    with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? _selectedClassId;

  // cache
  List<_ClassLite> _classes = [];
  List<_Student> _students = []; // RA + Nome
  Map<String, _Entry> _entries = {}; // ra -> entry (t1..t3 com atividades)
  bool _isSaving = false;

  late final TabController _tab;

  // Busca por RA
  final TextEditingController _raSearchCtrl = TextEditingController();
  String get _raQuery => _raSearchCtrl.text.trim();
  List<_Student> get _visibleStudents {
    final q = _raQuery;
    if (q.isEmpty) return _students;
    return _students.where((s) => s.ra.contains(q)).toList();
  }

  // Pesos default
  final Map<String, num> _termWeights = const {'t1': 0.3, 't2': 0.3, 't3': 0.4};
  final Map<String, num> _compWeights = const {'atividades': 0.6, 'prova': 0.4};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this); // T1..T3
    _loadClasses();
  }

  @override
  void dispose() {
    _tab.dispose();
    _raSearchCtrl.dispose();
    super.dispose();
  }

  // -------------------- Loads --------------------

  Future<void> _loadClasses() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final q = await _db.collection('classes').where('ownerUid', isEqualTo: uid).get();

    final list = <_ClassLite>[];
    for (final d in q.docs) {
      final data = d.data();
      final labelAny = (data['name'] ?? data['title'] ?? data['materia'] ?? data['subject'] ?? d.id);
      final label = '${labelAny ?? ''}';
      final rasDyn = (data['studentRAs'] as List?) ?? const [];
      list.add(
        _ClassLite(
          id: d.id,
          label: label,
          studentRAs: rasDyn.map((e) => '${e ?? ''}').toList(),
        ),
      );
    }

    setState(() {
      _classes = list;
      _selectedClassId = list.isNotEmpty ? list.first.id : null;
    });

    if (_selectedClassId != null) {
      final cls = list.firstWhere((e) => e.id == _selectedClassId);
      await _loadStudentsForClass(cls.id, cls.studentRAs);
      await _loadEntries();
    }
  }

  Future<void> _loadStudentsForClass(String cid, List<String> rasFromArray) async {
    final sub = await _db.collection('classes').doc(cid).collection('students').get();
    final list = <_Student>[];

    if (sub.docs.isNotEmpty) {
      for (final d in sub.docs) {
        final data = d.data();
        final ra = '${d.id}';
        final name = _pickName(data);
        list.add(_Student(ra: ra, name: name.isEmpty ? ra : name));
      }
    } else {
      for (final ra in rasFromArray) {
        String nome = '';
        final idx = await _db.collection('students_index').doc(ra).get();
        if (idx.exists) nome = _pickName(idx.data() ?? const {});
        list.add(_Student(ra: '$ra', name: nome.isEmpty ? '$ra' : nome));
      }
    }

    // Enriquecer nomes com users/ (se necessário)
    for (int i = 0; i < list.length; i++) {
      if (list[i].name == list[i].ra) {
        final ra = list[i].ra;
        final uq = await _db.collection('users').where('ra', isEqualTo: ra).limit(1).get();
        if (uq.docs.isNotEmpty) {
          final uname = _pickName(uq.docs.first.data());
          if (uname.isNotEmpty) list[i] = _Student(ra: '$ra', name: uname);
        }
      }
    }

    setState(() => _students = list..sort((a, b) => a.ra.compareTo(b.ra)));
  }

  String _pickName(Map<String, dynamic> data) {
    final v = (data['name'] ?? data['nome'] ?? data['displayName'] ?? data['fullName'] ?? data['studentName']);
    return '${v ?? ''}';
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
      final ra = '${data['studentRa'] ?? ''}';
      final scores = Map<String, dynamic>.from(data['scores'] ?? const {});

      final t1 = Map<String, dynamic>.from(scores['t1'] ?? const {});
      final t2 = Map<String, dynamic>.from(scores['t2'] ?? const {});
      final t3 = Map<String, dynamic>.from(scores['t3'] ?? const {});
      final b1 = Map<String, dynamic>.from(scores['b1'] ?? const {});
      final b2 = Map<String, dynamic>.from(scores['b2'] ?? const {});
      final b3 = Map<String, dynamic>.from(scores['b3'] ?? const {});

      List<num> _ativFromB(Map<String, dynamic> b) => [
            b['a1'] ?? 0,
            b['a2'] ?? 0,
            b['a3'] ?? 0,
          ].map((e) => (e ?? 0) as num).toList();

      _Term parseTerm(Map<String, dynamic> t, Map<String, dynamic> b) {
        if (t.isNotEmpty) {
          final raw = (t['atividades'] as List?) ?? const [];
          return _Term(
            atividades: raw.map((e) => (e ?? 0) as num).toList(),
            prova: (t['prova'] ?? 0) as num,
          );
        } else if (b.isNotEmpty) {
          return _Term(
            atividades: _ativFromB(b),
            prova: (b['prova'] ?? 0) as num,
          );
        } else {
          return _Term(atividades: const [], prova: 0);
        }
      }

      map[ra] = _Entry.fromDoc(
        id: d.id,
        ra: '$ra',
        t1: parseTerm(t1, b1),
        t2: parseTerm(t2, b2),
        t3: parseTerm(t3, b3),
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
          't1': {'atividades': e.t1.atividades, 'prova': e.t1.prova},
          't2': {'atividades': e.t2.atividades, 'prova': e.t2.prova},
          't3': {'atividades': e.t3.atividades, 'prova': e.t3.prova},
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (e.id == null) {
        final ref = _db.collection('grade_entries').doc();
        batch.set(ref, {...payload, 'createdAt': FieldValue.serverTimestamp()});
        _entries[ra] = e.copyWith(id: ref.id);
      } else {
        final ref = _db.collection('grade_entries').doc(e.id);
        batch.update(ref, payload);
      }
    }

    try {
      await batch.commit();
      final ok = await _publishStatsOneDoc();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Notas salvas e estatísticas atualizadas.'
                : 'Notas salvas. (Falhou ao atualizar estatísticas)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------- Publica estatísticas ----------
  Future<bool> _publishStats() async {
    if (_selectedClassId == null) return false;
    try {
      final medias = <double>[];
      for (final st in _students) {
        medias.add(_finalOf(st.ra).toDouble());
      }
      final avg = medias.isEmpty ? 0.0 : (medias.reduce((a, b) => a + b) / medias.length);
      final bins = List<int>.filled(10, 0);
      for (final m in medias) {
        final idx = m.floor().clamp(0, 9);
        bins[idx] += 1;
      }

      Map<String, dynamic> _sparseOf(_SparseStats s) => {
            'occurrences': s.occurrences,
            'consensus': s.consensus,
            'total': s.total,
          };

      Map<String, dynamic> _termSparse(int term) {
        final prova = _statsProvaTerm(term);
        final trabs = _statsTrabalhosTerm(term);
        return {'prova': _sparseOf(prova), 'trabalhos': _sparseOf(trabs)};
      }

      final sparseAll = {
        't1': _termSparse(1),
        't2': _termSparse(2),
        't3': _termSparse(3),
      };

      await _db.collection('class_stats').doc(_selectedClassId).set({
        'classId': _selectedClassId,
        'avg': avg,
        'bins': bins,
        'sparse': sparseAll,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _publishStatsOneDoc() async {
    if (_selectedClassId == null) return false;
    try {
      final medias = <double>[];
      for (final st in _students) {
        medias.add(_finalOf(st.ra).toDouble());
      }
      final avg = medias.isEmpty ? 0.0 : (medias.reduce((a, b) => a + b) / medias.length);
      final bins = List<int>.filled(10, 0);
      for (final m in medias) {
        final idx = m.floor().clamp(0, 9);
        bins[idx] += 1;
      }

      Map<String, dynamic> _sparseCountsForTerm(int term, {required bool trabalhos}) {
        final counts = List<int>.filled(11, 0);
        int total = 0;

        for (final st in _students) {
          final e = _entries[st.ra] ?? _Entry.empty(st.ra);
          final t = switch (term) { 1 => e.t1, 2 => e.t2, _ => e.t3 };

          double? valor;
          if (trabalhos) {
            if (t.atividades.isEmpty) continue;
            valor = _avgAtividades(t.atividades).toDouble();
          } else {
            final p = t.prova.toDouble();
            final hasAny = p > 0 || t.atividades.any((x) => x > 0);
            if (!hasAny) continue;
            valor = p;
          }

          final idx = valor.clamp(0, 10).round();
          counts[idx] += 1;
          total += 1;
        }

        int? consensus;
        if (total > 0) {
          int maxC = 0, maxIdx = 0;
          for (int i = 0; i <= 10; i++) {
            if (counts[i] > maxC) {
              maxC = counts[i];
              maxIdx = i;
            }
          }
          if (maxC > total / 2) consensus = maxIdx;
        }

        final occurrences = <int>[];
        for (int i = 0; i <= 10; i++) {
          if (counts[i] > 0) occurrences.add(i);
        }

        return {'occ': occurrences, 'cons': consensus};
      }

      Map<String, dynamic> _flatTerm(int term) {
        final p = _sparseCountsForTerm(term, trabalhos: false);
        final t = _sparseCountsForTerm(term, trabalhos: true);
        return {
          's_prova_t${term}_occ': List<int>.from(p['occ'] ?? const <int>[]),
          's_prova_t${term}_cons': p['cons'],
          's_trab_t${term}_occ': List<int>.from(t['occ'] ?? const <int>[]),
          's_trab_t${term}_cons': t['cons'],
        };
      }

      final payload = <String, dynamic>{
        'classId': _selectedClassId,
        'avg': avg,
        'bins': bins,
        ..._flatTerm(1),
        ..._flatTerm(2),
        ..._flatTerm(3),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('class_stats').doc(_selectedClassId).set(payload, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  // -------------------- Helpers de regra --------------------

  num _avgAtividades(List<num> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  num _termAvg(_Term t) =>
      _avgAtividades(t.atividades) * (_compWeights['atividades'] ?? 0.6) +
      t.prova * (_compWeights['prova'] ?? 0.4);

  bool _termVazio(_Term t) {
    final semAtividadesReais = t.atividades.isEmpty || t.atividades.every((x) => (x) == 0);
    return semAtividadesReais && (t.prova == 0);
  }

  num _customRound(num v) {
  // arredonda para o múltiplo de 0,5 mais próximo
  final r = (v * 2).round() / 2.0;
  // mantém dentro de 0..10 por segurança
  if (r < 0) return 0;
  if (r > 10) return 10;
  return r;
}


  num _finalOf(String ra) {
    final e = _entries[ra];
    if (e == null) return 0;

    final termos = <String, _Term>{'t1': e.t1, 't2': e.t2, 't3': e.t3};
    double somaPesos = 0, soma = 0;

    termos.forEach((k, t) {
      if (!_termVazio(t)) {
        final w = (_termWeights[k] ?? 0).toDouble();
        somaPesos += w;
        soma += _termAvg(t) * w;
      }
    });

    if (somaPesos == 0) return 0;
    return _customRound(soma / somaPesos);
  }

  String _fmt(num v) {
    if (v % 1 == 0) return v.toStringAsFixed(0);
    final s2 = v.toStringAsFixed(2);
    if (s2.endsWith('0')) return v.toStringAsFixed(1);
    return s2;
  }

  // ---------- ESTATÍSTICAS para o sheet ----------

  _SparseStats _statsProvaTerm(int term) {
    final counts = List<int>.filled(11, 0); // 0..10
    int total = 0;

    for (final st in _students) {
      final e = _entries[st.ra] ?? _Entry.empty(st.ra);
      final t = switch (term) { 1 => e.t1, 2 => e.t2, _ => e.t3 };
      final p = t.prova.toDouble();
      final hasAny = p > 0 || t.atividades.any((x) => x > 0);
      if (!hasAny) continue;

      final idx = p.clamp(0, 10).round();
      counts[idx] += 1;
      total += 1;
    }

    int? consensus;
    if (total > 0) {
      int maxC = 0, maxIdx = 0;
      for (int i = 0; i <= 10; i++) {
        if (counts[i] > maxC) { maxC = counts[i]; maxIdx = i; }
      }
      if (maxC > total / 2) consensus = maxIdx;
    }

    final occurrences = <int>[];
    for (int i = 0; i <= 10; i++) {
      if (counts[i] > 0) occurrences.add(i);
    }

    return _SparseStats(total: total, counts: counts, occurrences: occurrences, consensus: consensus);
  }

  _SparseStats _statsTrabalhosTerm(int term) {
    final counts = List<int>.filled(11, 0); // 0..10
    int total = 0;

    for (final st in _students) {
      final e = _entries[st.ra] ?? _Entry.empty(st.ra);
      final t = switch (term) { 1 => e.t1, 2 => e.t2, _ => e.t3 };
      if (t.atividades.isEmpty) continue;

      final mediaAluno = _avgAtividades(t.atividades).toDouble().clamp(0, 10);
      final idx = mediaAluno.round();
      counts[idx] += 1;
      total += 1;
    }

    int? consensus;
    if (total > 0) {
      int maxC = 0, maxIdx = 0;
      for (int i = 0; i <= 10; i++) {
        if (counts[i] > maxC) { maxC = counts[i]; maxIdx = i; }
      }
      if (maxC > total / 2) consensus = maxIdx;
    }

    final occurrences = <int>[];
    for (int i = 0; i <= 10; i++) {
      if (counts[i] > 0) occurrences.add(i);
    }

    return _SparseStats(total: total, counts: counts, occurrences: occurrences, consensus: consensus);
  }

  void _openStatsSheet() {
    final term = _tab.index + 1; // 1..3
    final prova = _statsProvaTerm(term);
    final trabs = _statsTrabalhosTerm(term);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _TermSparseStatsSheet(
                title: 'Trimestre $term',
                prova: prova,
                trabalhos: trabs,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------- UI (DESIGN POLIEDRO) --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 120,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Tooltip(
            message: 'Voltar',
            child: TextButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Voltar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(.10),
                side: const BorderSide(color: Colors.white24),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Estatísticas (Prova/Trabalhos)',
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: _openStatsSheet,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3E5FBF),
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving || _selectedClassId == null ? null : _saveAll,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Salvando...' : 'Salvar'),
            ),
          ),
        ],
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo imagem + gradiente
          Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/poliedro.png'),
                fit: BoxFit.cover,
              ),
              gradient: LinearGradient(
                colors: [const Color(0xFF0B091B).withOpacity(.92), const Color(0xFF0B091B).withOpacity(.92)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Watermark
          Center(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.12,
                child: Image.asset('assets/images/iconePoliedro.png', width: _watermarkSize(context), fit: BoxFit.contain),
              ),
            ),
          ),

          // Conteúdo centralizado
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _Glass(
                      radius: 18,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.calculate_outlined, color: Colors.white),
                              SizedBox(width: 10),
                              Text('Planilha manual (Trimestres)',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _GlassField(
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedClassId,
                                    items: _classes
                                        .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.label}')))
                                        .toList(),
                                    dropdownColor: const Color(0xFF17152A),
                                    style: const TextStyle(color: Colors.white),
                                    iconEnabledColor: Colors.white70,
                                    decoration: const InputDecoration(
                                      labelText: 'Turma',
                                      labelStyle: TextStyle(color: Colors.white70),
                                      border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                                    ),
                                    onChanged: (v) async {
                                      setState(() {
                                        _selectedClassId = v;
                                        _entries = {};
                                        _raSearchCtrl.clear();
                                      });
                                      if (v == null) return;
                                      final cls = _classes.firstWhere((e) => e.id == v);
                                      await _loadStudentsForClass(cls.id, cls.studentRAs);
                                      await _loadEntries();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 280,
                                  child: TextField(
                                    controller: _raSearchCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(20),
                                    ],
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'Buscar por RA',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                                      suffixIcon: (_raQuery.isEmpty)
                                          ? null
                                          : IconButton(
                                              tooltip: 'Limpar',
                                              icon: const Icon(Icons.close, color: Colors.white70),
                                              onPressed: () {
                                                setState(() => _raSearchCtrl.clear());
                                              },
                                            ),
                                      border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                                      fillColor: const Color(0xFF17152A),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _Glass(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          tabBarTheme: const TabBarThemeData(
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white60,
                            indicatorColor: Colors.white,
                          ),
                        ),
                        child: TabBar(
                          controller: _tab,
                          tabs: const [
                            Tab(text: 'Trimestre 1'),
                            Tab(text: 'Trimestre 2'),
                            Tab(text: 'Trimestre 3'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    _Glass(
                      radius: 18,
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        height: 600,
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dataTableTheme: DataTableThemeData(
                              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              dataTextStyle: const TextStyle(color: Colors.white),
                              headingRowColor: MaterialStatePropertyAll(Colors.white54.withOpacity(.11)),
                              dividerThickness: 0.6,
                            ),
                          ),
                          child: TabBarView(
                            controller: _tab,
                            children: [
                              _buildTableTri(term: 1),
                              _buildTableTri(term: 2),
                              _buildTableTri(term: 3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Widgets auxiliares (design) ----------

  double _watermarkSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 640) return (w * 1.15).clamp(420.0, 760.0);
    if (w < 1000) return (w * 0.82).clamp(520.0, 780.0);
    return (w * 0.55).clamp(700.0, 900.0);
  }

  Widget _GlassField({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121022).withOpacity(.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          padding: const EdgeInsets.all(10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTableTri({required int term}) {
    if (_selectedClassId == null) {
      return const Center(child: Text('Selecione uma turma', style: TextStyle(color: Colors.white70)));
    }

    final cols = const [
      DataColumn(label: Text('RA')),
      DataColumn(label: Text('Nome')),
      DataColumn(label: Text('Prova')),
      DataColumn(label: Text('Atividades')),
      DataColumn(label: Text('Média do Trim.')),
      DataColumn(label: Text('Média Final')),
    ];

    num termAvgOf(_Entry e) {
      final t = switch (term) { 1 => e.t1, 2 => e.t2, _ => e.t3 };
      return _termAvg(t);
    }

    final rows = _visibleStudents.map((st) {
      final ra = st.ra;
      final e = _entries.putIfAbsent(ra, () => _Entry.empty(ra));
      _Term t = switch (term) { 1 => e.t1, 2 => e.t2, _ => e.t3 };

      Widget atividadesCell() {
        const double cellHeight = 120;
        return StatefulBuilder(
          builder: (ctx, setSB) {
            return SizedBox(
              height: cellHeight,
              width: 300,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (int i = 0; i < t.atividades.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('A', style: TextStyle(color: Colors.white70)),
                          Text('${i + 1}:', style: const TextStyle(color: Colors.white70)),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 64,
                            child: _ScoreField(
                              value: t.atividades[i].toDouble(),
                              onChanged: (novo) {
                                t = t.copyWith(atividades: [
                                  ...t.atividades.take(i),
                                  novo,
                                  ...t.atividades.skip(i + 1),
                                ]);
                                setSB(() {});
                                setState(() {
                                  _entries[ra] = switch (term) {
                                    1 => e.copyWith(t1: t),
                                    2 => e.copyWith(t2: t),
                                    _ => e.copyWith(t3: t),
                                  };
                                });
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remover',
                            onPressed: () {
                              t = t.copyWith(atividades: [
                                ...t.atividades.take(i),
                                ...t.atividades.skip(i + 1),
                              ]);
                              setSB(() {});
                              setState(() {
                                _entries[ra] = switch (term) {
                                  1 => e.copyWith(t1: t),
                                  2 => e.copyWith(t2: t),
                                  _ => e.copyWith(t3: t),
                                };
                              });
                            },
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () {
                        t = t.copyWith(atividades: [...t.atividades, 0]);
                        setSB(() {});
                        setState(() {
                          _entries[ra] = switch (term) {
                            1 => e.copyWith(t1: t),
                            2 => e.copyWith(t2: t),
                            _ => e.copyWith(t3: t),
                          };
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar atividade'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }

      return DataRow(cells: [
        DataCell(Text('$ra')),
        DataCell(Text('${st.name}')),
        DataCell(SizedBox(
          width: 70,
          child: _ScoreField(
            value: t.prova.toDouble(),
            onChanged: (novo) {
              final nt = t.copyWith(prova: novo);
              setState(() {
                _entries[ra] = switch (term) {
                  1 => e.copyWith(t1: nt),
                  2 => e.copyWith(t2: nt),
                  _ => e.copyWith(t3: nt),
                };
              });
            },
          ),
        )),
        DataCell(atividadesCell()),
        DataCell(Text(_fmt(termAvgOf(e)))),
        DataCell(Text(_fmt(_finalOf(ra)))),
      ]);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _raQuery.isEmpty
                ? 'Dica: edite os valores, use “Adicionar atividade” e clique em “Salvar”.'
                : 'Filtrando por RA: "${_raQuery}"  •  ${_visibleStudents.length} aluno(s).',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: cols,
              rows: rows,
              columnSpacing: 24,
              horizontalMargin: 16,
              dataRowMinHeight: 72,
              dataRowMaxHeight: 160,
              headingRowHeight: 44,
              dividerThickness: 0.7,
            ),
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

class _Term {
  final List<num> atividades;
  final num prova;
  _Term({required this.atividades, required this.prova});

  _Term copyWith({List<num>? atividades, num? prova}) =>
      _Term(atividades: atividades ?? this.atividades, prova: prova ?? this.prova);
}

class _Entry {
  final String? id;
  final String ra;
  final _Term t1;
  final _Term t2;
  final _Term t3;

  _Entry({required this.id, required this.ra, required this.t1, required this.t2, required this.t3});

  factory _Entry.empty(String ra) => _Entry(
        id: null,
        ra: '$ra',
        t1: _Term(atividades: const [], prova: 0),
        t2: _Term(atividades: const [], prova: 0),
        t3: _Term(atividades: const [], prova: 0),
      );

  factory _Entry.fromDoc({required String id, required String ra, required _Term t1, required _Term t2, required _Term t3}) =>
      _Entry(id: id, ra: '$ra', t1: t1, t2: t2, t3: t3);

  _Entry copyWith({String? id, _Term? t1, _Term? t2, _Term? t3}) {
    return _Entry(id: id ?? this.id, ra: ra, t1: t1 ?? this.t1, t2: t2 ?? this.t2, t3: t3 ?? this.t3);
  }
}

/* ===== Campo numérico ===== */
class _ScoreField extends StatefulWidget {
  final double value;
  final ValueChanged<num> onChanged;
  const _ScoreField({required this.value, required this.onChanged, super.key});

  @override
  State<_ScoreField> createState() => _ScoreFieldState();
}

class _ScoreFieldState extends State<_ScoreField> {
  late final TextEditingController _c;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: _fmtHalf(widget.value));
    _lastText = _c.text;
  }

  @override
  void didUpdateWidget(covariant _ScoreField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = _fmtHalf(widget.value);
    if (_lastText != now && _c.text != now) {
      _c.text = now;
      _lastText = now;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // formata para 0,5 (ex.: 7 -> "7", 7.25 -> "7.5")
  static String _fmtHalf(num v) {
    final snapped = (v * 2).round() / 2.0;
    final hasHalf = (snapped * 2).round() % 2 != 0; // true se termina em .5
    return hasHalf ? snapped.toStringAsFixed(1) : snapped.toStringAsFixed(0);
  }

  void _applyAndNotify(double parsed) {
    // clamp e snap para 0,5
    double clamped = parsed.clamp(0, 10);
    double half = (clamped * 2).round() / 2.0;

    // atualiza texto já formatado
    final fixed = _fmtHalf(half);
    if (_c.text != fixed) {
      _c.value = _c.value.copyWith(
        text: fixed,
        selection: TextSelection.collapsed(offset: fixed.length),
      );
    }
    _lastText = _c.text;

    // notifica com valor “meio a meio”
    widget.onChanged(half);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 64,
      child: TextField(
        controller: _c,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          // deixa digitar até 2 dígitos e 1 decimal (a gente snapa para .0 ou .5)
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}([.,]\d{0,2})?$')),
        ],
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: cs.surface.withOpacity(.20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white54, width: 1.2),
          ),
          hintText: '0–10',
          hintStyle: const TextStyle(color: Colors.white54),
        ),
        onChanged: (txt) {
          final s = txt.replaceAll(',', '.').trim();
          if (s.isEmpty) {
            _lastText = txt;
            return;
          }
          final parsed = double.tryParse(s);
          if (parsed == null) {
            _lastText = txt;
            return;
          }
          _applyAndNotify(parsed);
        },
        onEditingComplete: () {
          // ao finalizar a edição, força o snap também
          final s = _c.text.replaceAll(',', '.').trim();
          final parsed = double.tryParse(s);
          if (parsed != null) _applyAndNotify(parsed);
        },
      ),
    );
  }
}


/* ===== Estatística esparsa ===== */
class _SparseStats {
  final int total;
  final List<int> counts;
  final List<int> occurrences;
  final int? consensus;
  const _SparseStats({required this.total, required this.counts, required this.occurrences, required this.consensus});
}

class _TermSparseStatsSheet extends StatelessWidget {
  final String title;
  final _SparseStats prova;
  final _SparseStats trabalhos;
  const _TermSparseStatsSheet({required this.title, required this.prova, required this.trabalhos});

  @override
  Widget build(BuildContext context) {
    String _avgIfConsensus(_SparseStats s) => (s.consensus == null) ? '' : 'média = ${s.consensus}';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$title', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),

          Text('Prova', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          _SparseScale(labels: prova.occurrences, consensus: prova.consensus),
          if (_avgIfConsensus(prova).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_avgIfConsensus(prova), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),

          Text('Trabalhos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          _SparseScale(labels: trabalhos.occurrences, consensus: trabalhos.consensus),
          if (_avgIfConsensus(trabalhos).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_avgIfConsensus(trabalhos), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SparseScale extends StatelessWidget {
  final List<int> labels;
  final int? consensus;
  const _SparseScale({required this.labels, required this.consensus});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _SparseScalePainter(labels: labels, consensus: consensus),
      ),
    );
  }
}

class _SparseScalePainter extends CustomPainter {
  final List<int> labels; // inteiros a mostrar
  final int? consensus;   // destaque (se houver)
  _SparseScalePainter({required this.labels, required this.consensus});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final start = Offset(24, y);
    final end = Offset(size.width - 24, y);
    final span = end.dx - start.dx;

    // linha base com gradiente + leve glow
    final shader = const LinearGradient(
      colors: [Color(0xFF6EA8FF), Color(0xFFB072FF)],
    ).createShader(Rect.fromPoints(start, end));
    final axis = Paint()
      ..shader = shader
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final axisGlow = Paint()
      ..color = const Color(0x226EA8FF)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, axisGlow);
    canvas.drawLine(start, end, axis);

    for (final i in labels) {
      final x = start.dx + span * (i / 10.0);
      final isC = (consensus != null && i == consensus);

      // tick
      final tick = Paint()
        ..color = isC ? const Color(0xFF6EA8FF) : const Color(0xFFB0B0B0)
        ..strokeWidth = isC ? 3 : 1.6;
      canvas.drawLine(Offset(x, y - 8), Offset(x, y + 8), tick);

      // bolinha
      final dot = Paint()..color = isC ? const Color(0xFF6EA8FF) : const Color(0xFFB0B0B0);
      canvas.drawCircle(Offset(x, y - 14), isC ? 5 : 3, dot);

      if (isC) {
        final halo = Paint()..color = const Color(0x446EA8FF);
        canvas.drawCircle(Offset(x, y - 14), 12, halo);
      }

      // número
      final tp = TextPainter(
        text: TextSpan(
          text: '$i',
          style: TextStyle(
            fontSize: isC ? 16 : 13,
            fontWeight: isC ? FontWeight.w800 : FontWeight.w600,
            color: isC ? const Color(0xFF6EA8FF) : const Color(0xFF7A7A7A),
            letterSpacing: .2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y + 10));
    }

    // label de média (se houver consenso)
    if (consensus != null) {
      final label = TextPainter(
        text: const TextSpan(
          text: 'média',
          style: TextStyle(color: Color(0xFF8FB6FF), fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final value = TextPainter(
        text: TextSpan(
          text: ' = $consensus',
          style: const TextStyle(color: Color(0xFF8FB6FF), fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final totalW = label.width + value.width;
      final left = (size.width - totalW) / 2;
      label.paint(canvas, Offset(left, y - 34));
      value.paint(canvas, Offset(left + label.width, y - 34));
    }
  }

  @override
  bool shouldRepaint(covariant _SparseScalePainter old) =>
      old.labels != labels || old.consensus != consensus;
}

/* ========================= Glass helper ========================= */
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const _Glass({required this.child, this.padding, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121022).withOpacity(.18),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(.10)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 16)),
            ],
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
