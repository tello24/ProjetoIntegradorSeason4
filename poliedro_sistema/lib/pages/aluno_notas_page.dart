import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AlunoNotasPage extends StatefulWidget {
  const AlunoNotasPage({super.key});
  @override
  State<AlunoNotasPage> createState() => _AlunoNotasPageState();
}

class _AlunoNotasPageState extends State<AlunoNotasPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? _selectedClassId;
  String _myRA = '';

  List<_ClassLite> _classes = [];
  bool _loading = true;

  // aba atual (0..2) — usado no sheet
  int _tabIndex = 0;

  // mesmos pesos
  final Map<String, num> _termWeights = const {'t1': 0.3, 't2': 0.3, 't3': 0.4};
  final Map<String, num> _compWeights = const {'atividades': 0.6, 'prova': 0.4};

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    // RA do aluno
    final me = await _db.collection('users').doc(uid).get();
    _myRA = '${me.data()?['ra'] ?? ''}';

    // turmas
    final q = await _db
        .collection('classes')
        .where('studentRAs', arrayContains: _myRA)
        .get();

    final list = <_ClassLite>[];
    for (final d in q.docs) {
      final data = d.data();
      final label =
          (data['name'] ?? data['title'] ?? data['materia'] ?? data['subject'] ?? d.id)
              .toString();
      list.add(_ClassLite(id: d.id, label: label));
    }

    setState(() {
      _classes = list;
      _selectedClassId = list.isNotEmpty ? list.first.id : null;
      _loading = false;
    });
  }

  // =================== Cálculos (iguais ao professor) ===================

  num _avgAtividades(List<num> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  num _termAvg(_Term t) =>
      _avgAtividades(t.atividades) * (_compWeights['atividades'] ?? 0.6) +
      t.prova * (_compWeights['prova'] ?? 0.4);

  bool _termVazio(_Term t) {
    final semAtividadesReais = t.atividades.isEmpty || t.atividades.every((x) => (x) == 0);
    return semAtividadesReais && (t.prova == 0);
  }

  num _customRound(num v) {
    final base = v.floor();
    final frac = v - base;
    if (frac < 0.35) return base;
    if (frac < 0.50) return base + 0.5;
    if (frac < 0.75) return double.parse(v.toStringAsFixed(2));
    return base + 1;
  }

  num _finalRounded(_EntryView e) {
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

  // =============================== UI ===============================

  @override
  Widget build(BuildContext context) {
    final items = _classes
        .map((c) => DropdownMenuItem<String>(
              value: c.id,
              child: Text(c.label, overflow: TextOverflow.ellipsis),
            ))
        .toList();
    final String? safeValue =
        items.any((it) => it.value == _selectedClassId) ? _selectedClassId : null;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,

  // espaço pra caber o botão "pill"
  leadingWidth: 120,
  leading: Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Tooltip(
      message: 'Voltar',
      child: TextButton.icon(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
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
      tooltip: 'Estatísticas da turma',
      onPressed: _openStatsSheet,
      icon: const Icon(Icons.bar_chart, color: Colors.white),
    ),
  ],

  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(56),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: _Glass(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Theme(
          data: Theme.of(context).copyWith(
            tabBarTheme: const TabBarThemeData(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
            ),
          ),
          child: TabBar(
            onTap: (i) => setState(() => _tabIndex = i),
            tabs: const [
              Tab(text: 'Trimestre 1'),
              Tab(text: 'Trimestre 2'),
              Tab(text: 'Trimestre 3'),
            ],
          ),
        ),
      ),
    ),
  ),
),

        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fundo com gradiente + imagem
            Container(
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/poliedro.png'),
                  fit: BoxFit.cover,
                ),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0B091B).withOpacity(.92),
                    const Color(0xFF0B091B).withOpacity(.92),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Marca d’água
            Center(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.10,
                  child: Image.asset(
                    'assets/images/iconePoliedro.png',
                    width: _watermarkSize(context),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            children: [
                              // seletor turma
                              _Glass(
                                radius: 16,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.class_, color: Colors.white),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: safeValue,
                                        items: items,
                                        dropdownColor: const Color(0xFF17152A),
                                        style: const TextStyle(color: Colors.white),
                                        iconEnabledColor: Colors.white70,
                                        decoration: const InputDecoration(
                                          labelText: 'Turma',
                                          labelStyle: TextStyle(color: Colors.white70),
                                          border: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.white24),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.white24),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.white54),
                                          ),
                                        ),
                                        onChanged: (v) =>
                                            setState(() => _selectedClassId = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              Expanded(
                                child: (_selectedClassId == null || _myRA.isEmpty)
                                    ? const _GlassMessage('Selecione uma turma')
                                    : StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>>(
                                        stream: _db
                                            .collection('grade_entries')
                                            .where('classId',
                                                isEqualTo: _selectedClassId)
                                            .where('studentRa', isEqualTo: _myRA)
                                            .limit(1)
                                            .snapshots(),
                                        builder: (context, snap) {
                                          if (snap.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                                child:
                                                    CircularProgressIndicator());
                                          }
                                          if (!snap.hasData ||
                                              snap.data!.docs.isEmpty) {
                                            return const _GlassMessage(
                                                'Nenhuma nota lançada ainda.');
                                          }

                                          try {
                                            final doc = snap.data!.docs.first;
                                            final Map<String, dynamic> raw =
                                                Map<String, dynamic>.from(
                                                    doc.data());
                                            final Map<String, dynamic> scores =
                                                _asMap(raw['scores']);
                                            final entry =
                                                _EntryView.fromScores(scores);

                                            return TabBarView(
                                              children: [
                                                _buildTrimView(entry.t1, entry),
                                                _buildTrimView(entry.t2, entry),
                                                _buildTrimView(entry.t3, entry),
                                              ],
                                            );
                                          } catch (e) {
                                            return _GlassMessage(
                                                'Erro ao interpretar suas notas.\n$e');
                                          }
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Views ----------

  Widget _buildTrimView(_Term t, _EntryView e) {
    final mTrim = _termAvg(t);
    final mFinal = _finalRounded(e);

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        // Atividades
        _Glass(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Atividades'),
              const SizedBox(height: 10),
              if (t.atividades.isEmpty)
                const Text('—', style: TextStyle(color: Colors.white60))
              else
                ChipTheme(
                  data: ChipTheme.of(context).copyWith(
                    backgroundColor: const Color(0xFF2A2750).withOpacity(.55),
                    disabledColor: const Color(0xFF2A2750).withOpacity(.35),
                    labelStyle: const TextStyle(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: const StadiumBorder(
                      side: BorderSide(color: Colors.white24),
                    ),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (int i = 0; i < t.atividades.length; i++)
                        Chip(label: Text('A${i + 1}: ${_fmt(t.atividades[i])}')),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Métricas (centralizadas)
        Row(
          children: [
            Expanded(child: _MetricCard(title: 'Prova', value: _fmt(t.prova))),
            const SizedBox(width: 10),
            Expanded(
                child: _MetricCard(
                    title: 'Média do Trimestre', value: _fmt(mTrim))),
            const SizedBox(width: 10),
            Expanded(
                child:
                    _MetricCard(title: 'Média Final', value: _fmt(mFinal))),
          ],
        ),
      ],
    );
  }

  // ---------- Estatística: igual à do professor ----------
  void _openStatsSheet() {
    if (_selectedClassId == null) return;

    final termIndex = _tabIndex; // 0..2
    final termNum = termIndex + 1;
    final cid = _selectedClassId!;

    List<int> _asIntList(dynamic v) {
      if (v is List<int>) return v;
      if (v is List) return v.map((e) => int.tryParse('$e') ?? 0).toList();
      return <int>[];
    }

    int? _asIntOrNull(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse('$v');
    }

    String _avgIfConsensus(int? c) => (c == null) ? '' : 'média = $c';

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
              child: StreamBuilder<
                  DocumentSnapshot<Map<String, dynamic>>>(
                stream: _db.collection('class_stats').doc(cid).snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator()));
                  }

                  if (snap.hasError) {
                    return Text('Erro ao ler estatísticas: ${snap.error}',
                        style: const TextStyle(color: Colors.redAccent));
                  }

                  if (!snap.hasData || !snap.data!.exists) {
                    return const Text('Sem estatísticas desta turma ainda.');
                  }

                  final data = snap.data!.data() ?? {};

                  try {
                    // Flatten
                    final kProvaOcc = 's_prova_t${termNum}_occ';
                    final kProvaCon = 's_prova_t${termNum}_cons';
                    final kTrabOcc = 's_trab_t${termNum}_occ';
                    final kTrabCon = 's_trab_t${termNum}_cons';

                    List<int> provaOcc = _asIntList(data[kProvaOcc]);
                    int? provaCon = _asIntOrNull(data[kProvaCon]);
                    List<int> trabOcc = _asIntList(data[kTrabOcc]);
                    int? trabCon = _asIntOrNull(data[kTrabCon]);

                    // Nested fallback
                    if (provaOcc.isEmpty && trabOcc.isEmpty) {
                      final sparse = (data['sparse'] is Map)
                          ? Map<String, dynamic>.from(data['sparse'])
                          : const <String, dynamic>{};
                      final termMap = (sparse['t$termNum'] is Map)
                          ? Map<String, dynamic>.from(sparse['t$termNum'])
                          : const <String, dynamic>{};
                      final prova = (termMap['prova'] is Map)
                          ? Map<String, dynamic>.from(termMap['prova'])
                          : const <String, dynamic>{};
                      final trabs = (termMap['trabalhos'] is Map)
                          ? Map<String, dynamic>.from(termMap['trabalhos'])
                          : const <String, dynamic>{};

                      provaOcc = _asIntList(prova['occurrences']);
                      provaCon = _asIntOrNull(prova['consensus']);
                      trabOcc = _asIntList(trabs['occurrences']);
                      trabCon = _asIntOrNull(trabs['consensus']);
                    }

                    final hasSparse = provaOcc.isNotEmpty || trabOcc.isNotEmpty;

                    if (hasSparse) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Trimestre $termNum',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),

                            Text('Prova',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            _SparseScaleFancy(labels: provaOcc, consensus: provaCon),
                            if (_avgIfConsensus(provaCon).isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(_avgIfConsensus(provaCon),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFF3772FF),
                                      fontWeight: FontWeight.w700)),
                            ],
                            const SizedBox(height: 16),

                            Text('Trabalhos',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            _SparseScaleFancy(labels: trabOcc, consensus: trabCon),
                            if (_avgIfConsensus(trabCon).isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(_avgIfConsensus(trabCon),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFF3772FF),
                                      fontWeight: FontWeight.w700)),
                            ],
                          ],
                        ),
                      );
                    }

                    // Fallback: histograma avg/bins
                    final avg = (data['avg'] ?? 0).toDouble();
                    final bins = List<int>.from(List.from(data['bins'] ?? List.filled(10, 0)));
                    final maxCount = bins.isEmpty ? 1 : bins.reduce((a, b) => a > b ? a : b);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Média da turma: ${avg.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: CustomPaint(
                            painter: _HistogramPainterFancy(
                              bins: bins,
                              maxCount: maxCount,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Eixo X: faixa de média (0–10) • Eixo Y: quantidade de alunos',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  } catch (e) {
                    return Text('Erro ao montar estatística: $e',
                        style: const TextStyle(color: Colors.redAccent));
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Safe converters ----------
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  double _watermarkSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 640) return (w * 1.10).clamp(380.0, 700.0);
    if (w < 1000) return (w * 0.80).clamp(520.0, 780.0);
    return (w * 0.55).clamp(700.0, 900.0);
  }
}

/* ======================= modelos/parse ======================= */
class _ClassLite {
  final String id;
  final String label;
  _ClassLite({required this.id, required this.label});
}

class _Term {
  final List<num> atividades;
  final num prova;
  const _Term({required this.atividades, required this.prova});

  factory _Term.fromMap(Map<String, dynamic>? m) {
    final mm = (m == null) ? <String, dynamic>{} : Map<String, dynamic>.from(m);
    final atividades = mm.containsKey('atividades')
        ? List<num>.from(List.from(mm['atividades'] ?? const []))
        : <num>[];
    final provaRaw = mm['prova'];
    final prova = (provaRaw is num) ? provaRaw : (num.tryParse('$provaRaw') ?? 0);
    return _Term(atividades: atividades, prova: prova);
  }
}

class _EntryView {
  final _Term t1, t2, t3;
  const _EntryView({required this.t1, required this.t2, required this.t3});

  factory _EntryView.fromScores(Map<String, dynamic> scoresAny) {
    final scores = Map<String, dynamic>.from(scoresAny);

    Map<String, dynamic> _m(dynamic v) =>
        (v is Map<String, dynamic>) ? v : (v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{});

    List<num> _ativFromB(Map<String, dynamic> b) => <num>[
          b['a1'] is num ? b['a1'] as num : (num.tryParse('${b['a1']}') ?? 0),
          b['a2'] is num ? b['a2'] as num : (num.tryParse('${b['a2']}') ?? 0),
          b['a3'] is num ? b['a3'] as num : (num.tryParse('${b['a3']}') ?? 0),
        ];

    _Term parseTerm(dynamic t, Map<String, dynamic> bFallback) {
      final tm = _m(t);
      if (tm.isNotEmpty) {
        return _Term.fromMap(tm);
      } else if (bFallback.isNotEmpty) {
        final atividades = _ativFromB(bFallback);
        final provaRaw = bFallback['prova'];
        final prova = (provaRaw is num) ? provaRaw : (num.tryParse('$provaRaw') ?? 0);
        return _Term(atividades: atividades, prova: prova);
      } else {
        return const _Term(atividades: [], prova: 0);
      }
    }

    final t1 = parseTerm(scores['t1'], _m(scores['b1']));
    final t2 = parseTerm(scores['t2'], _m(scores['b2']));
    final t3 = parseTerm(scores['t3'], _m(scores['b3']));

    return _EntryView(t1: t1, t2: t2, t3: t3);
  }

  factory _EntryView.empty() => const _EntryView(
        t1: _Term(atividades: [], prova: 0),
        t2: _Term(atividades: [], prova: 0),
        t3: _Term(atividades: [], prova: 0),
      );
}

/* ===== ajuda p/ UI ===== */
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  const _MetricCard({required this.title, required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 28,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassMessage extends StatelessWidget {
  final String msg;
  const _GlassMessage(this.msg, {super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: _Glass(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

/* ===== escala esparsa — versão “bonita” (igual ao prof) ===== */
class _SparseScaleFancy extends StatelessWidget {
  final List<int> labels;
  final int? consensus;
  const _SparseScaleFancy({required this.labels, required this.consensus, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: CustomPaint(
        painter: _SparseScaleFancyPainter(labels: labels, consensus: consensus),
      ),
    );
  }
}

class _SparseScaleFancyPainter extends CustomPainter {
  final List<int> labels;
  final int? consensus;
  _SparseScaleFancyPainter({required this.labels, required this.consensus});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final start = Offset(24, y);
    final end = Offset(size.width - 24, y);
    final span = end.dx - start.dx;

    // linha base com gradiente + glow
    final shader = const LinearGradient(
      colors: [Color(0xFF6EA8FF), Color(0xFFB072FF)],
    ).createShader(Rect.fromPoints(start, end));
    final axisGlow = Paint()
      ..color = const Color(0x226EA8FF)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final axis = Paint()
      ..shader = shader
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, axisGlow);
    canvas.drawLine(start, end, axis);

    for (final i in labels) {
      final x = start.dx + span * (i / 10.0);
      final isC = (consensus != null && i == consensus);

      final tick = Paint()
        ..color = isC ? const Color(0xFF6EA8FF) : const Color(0xFFB0B0B0)
        ..strokeWidth = isC ? 3 : 1.6;
      canvas.drawLine(Offset(x, y - 8), Offset(x, y + 8), tick);

      final dot = Paint()..color = isC ? const Color(0xFF6EA8FF) : const Color(0xFFB0B0B0);
      canvas.drawCircle(Offset(x, y - 14), isC ? 5 : 3, dot);
      if (isC) {
        final halo = Paint()..color = const Color(0x446EA8FF);
        canvas.drawCircle(Offset(x, y - 14), 12, halo);
      }

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

    if (consensus != null) {
      final label = TextPainter(
        text: TextSpan(
          text: 'média = $consensus',
          style: const TextStyle(color: Color(0xFF8FB6FF), fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(size.width / 2 - label.width / 2, y - 34));
    }
  }

  @override
  bool shouldRepaint(covariant _SparseScaleFancyPainter old) =>
      old.labels != labels || old.consensus != consensus;
}

/* ===== histograma com gradiente ===== */
class _HistogramPainterFancy extends CustomPainter {
  final List<int> bins;
  final int maxCount;
  _HistogramPainterFancy({required this.bins, required this.maxCount});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 24.0;
    final chartW = size.width - padding * 2;
    final chartH = size.height - padding * 2;
    final origin = Offset(padding, size.height - padding);

    final axis = Paint()
      ..color = const Color(0xFF4D4A63)
      ..strokeWidth = 1.2;

    canvas.drawLine(origin, Offset(padding + chartW, origin.dy), axis);
    canvas.drawLine(origin, Offset(origin.dx, padding), axis);

    if (bins.isEmpty || maxCount <= 0) return;

    final n = bins.length;
    final barW = chartW / (n * 1.25);
    final gap = barW * 0.25;

    for (int i = 0; i < n; i++) {
      final x = padding + i * (barW + gap);
      final h = (bins[i] / maxCount) * (chartH * 0.9);

      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, origin.dy - h, barW, h),
        const Radius.circular(6),
      );
      final shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6EA8FF), Color(0xFF8B78FF)],
      ).createShader(r.outerRect);

      final bar = Paint()..shader = shader;
      canvas.drawRRect(r, bar);

      // label X
      final tp = TextPainter(
        text: const TextSpan(
          text: '',
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final lx = TextPainter(
        text: TextSpan(
          text: '$i',
          style: const TextStyle(fontSize: 10, color: Colors.black87),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lx.paint(canvas, Offset(x + barW / 2 - lx.width / 2, origin.dy + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _HistogramPainterFancy old) =>
      old.bins != bins || old.maxCount != maxCount;
}

/* ========================= Glass helper ========================= */
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const _Glass({required this.child, this.padding, this.radius = 20, super.key});

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
