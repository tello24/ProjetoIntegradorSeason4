// lib/pages/aluno_notas_da_turma_page.dart

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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


class AlunoNotasDaTurmaPage extends StatefulWidget {
  final String turmaId;
  final String nomeTurma;

  const AlunoNotasDaTurmaPage({
    super.key,
    required this.turmaId,
    required this.nomeTurma,
  });

  @override
  State<AlunoNotasDaTurmaPage> createState() => _AlunoNotasDaTurmaPageState();
}

class _AlunoNotasDaTurmaPageState extends State<AlunoNotasDaTurmaPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String _myRA = '';
  bool _loadingRA = true;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _gradeEntryStream;

  final Map<String, num> _termWeights = const {'t1': 0.3, 't2': 0.3, 't3': 0.4};
  final Map<String, num> _compWeights = const {'atividades': 0.6, 'prova': 0.4};

  @override
  void initState() {
    super.initState();
    _loadRAAndSetupStream();
  }

  Future<void> _loadRAAndSetupStream() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingRA = false);
      return;
    }

    try {
      final me = await _db.collection('users').doc(uid).get();
      _myRA = '${me.data()?['ra'] ?? ''}';

      if (_myRA.isNotEmpty) {
        _gradeEntryStream = _db
            .collection('grade_entries')
            .where('classId', isEqualTo: widget.turmaId)
            .where('studentRa', isEqualTo: _myRA)
            .limit(1)
            .snapshots();
      }
    } catch (e) {
      print("Erro ao carregar RA: $e");
    } finally {
      if (mounted) {
        setState(() => _loadingRA = false);
      }
    }
  }

  // =================== Cálculos ===================
  num _avgAtividades(List<num> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  num _termAvg(_Term t) =>
      _avgAtividades(t.atividades) * (_compWeights['atividades'] ?? 0.6) +
      t.prova * (_compWeights['prova'] ?? 0.4);

  bool _termVazio(_Term t) {
    final semAtividadesReais = t.atividades.isEmpty || t.atividades.every((x) => (x) == 0);
    return semAtividadesReais && (t.prova == 0);
  }

  num _customRound(num v) {
    final r = (v * 2).round() / 2.0;
    if (r < 0) return 0;
    if (r > 10) return 10;
    return r;
  }

  num _snapHalf(num v) {
    final r = (v * 2).round() / 2.0;
    if (r < 0) return 0;
    if (r > 10) return 10;
    return r;
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
    final h = _snapHalf(v);
    if (h % 1 == 0) return h.toStringAsFixed(0);
    return h.toStringAsFixed(1);
  }

  // =============================== UI ===============================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          centerTitle: true, 
          title: Padding( 
            padding: const EdgeInsets.only(top:0), 
            child: Text(
              'Notas de ${widget.nomeTurma}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _BackButton(onTap: () => Navigator.maybePop(context)),
          leadingWidth: 136,
          automaticallyImplyLeading: false,
          actions: [ 
            SizedBox(width: 136),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), 
                  child: _Glass(
                    radius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        tabBarTheme: const TabBarThemeData(
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          indicatorColor: Colors.white,
                        ),
                      ),
                      child: const TabBar(
                        isScrollable: false,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorWeight: 2,
                        tabs: [
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
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _Bg(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), 
                    child: Column( 
                      children: [
                        Expanded(
                          child: _loadingRA
                              ? const Center(child: CircularProgressIndicator())
                              : (_myRA.isEmpty || _gradeEntryStream == null)
                                  ? const _GlassMessage('RA não encontrado.')
                                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                      stream: _gradeEntryStream,
                                      builder: (context, snap) {
                                        if (snap.connectionState == ConnectionState.waiting) {
                                          return const Center(child: CircularProgressIndicator());
                                        }
                                        if (snap.hasError) {
                                          return _GlassMessage('Erro ao carregar notas: ${snap.error}');
                                        }
                                        if (!snap.hasData || snap.data!.docs.isEmpty) {
                                          return const _GlassMessage('Nenhuma nota lançada para esta turma ainda.');
                                        }

                                        try {
                                          final doc = snap.data!.docs.first;
                                          final Map<String, dynamic> raw = Map<String, dynamic>.from(doc.data());
                                          final Map<String, dynamic> scores = _asMap(raw['scores']);
                                          final entry = _EntryView.fromScores(scores);

                                          return TabBarView(
                                            children: [
                                              _buildTrimView(entry.t1, entry),
                                              _buildTrimView(entry.t2, entry),
                                              _buildTrimView(entry.t3, entry),
                                            ],
                                          );
                                        } catch (e) {
                                          return _GlassMessage('Erro ao interpretar suas notas.\n$e');
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
    final mTrim = _snapHalf(_termAvg(t));
    final mFinal = _finalRounded(e);

    return ListView(
      padding: const EdgeInsets.all(10), 
      children: [
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
        Row(
          children: [
            Expanded(child: _MetricCard(title: 'Prova', value: _fmt(t.prova))),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(title: 'Média do Trimestre', value: _fmt(mTrim))),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(title: 'Média Final', value: _fmt(mFinal))),
          ],
        ),
      ],
    );
  }

  // ---------- Safe converters (copiados) ----------
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }
}


// ----- Widgets de UI (copiados/adaptados) -----

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
      label: const Text('Voltar'),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(.12),
        elevation: 0,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
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
  const _MetricCard({required this.title, required this.value});

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
  const _GlassMessage(this.msg);
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

class _Bg extends StatelessWidget {
  const _Bg();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(image: AssetImage('assets/images/poliedro.png'), fit: BoxFit.cover),
        gradient: LinearGradient(
          colors: [const Color(0xFF0B091B).withOpacity(.88), const Color(0xFF0B091B).withOpacity(.88)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}