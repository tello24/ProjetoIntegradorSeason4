import 'dart:ui';

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
    const pageTitle = 'Selecione a matéria';

    // Carregando RA
    if (_ra == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _appBar(context),
        body: Stack(
          fit: StackFit.expand,
          children: const [
            _Bg(),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    // Sem RA cadastrado
    if (_ra!.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _appBar(context),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _Bg(),
            Column(
              children: [
                const SizedBox(height: kToolbarHeight + 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: _Glass(
                    radius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_outlined, color: Colors.white70),
                        const SizedBox(width: 8),
                        const Text(
                          pageTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _StateCard(
                      icon: Icons.perm_identity,
                      title: 'RA não cadastrado',
                      subtitle: 'Peça para o professor atualizar seu RA no cadastro.',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Stream de turmas onde o RA está matriculado
    final stream = FirebaseFirestore.instance
        .collection('classes')
        .where('studentRAs', arrayContains: _ra) // mantém a lógica original
        .snapshots();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _appBar(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Bg(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              Widget content;

              if (snap.connectionState == ConnectionState.waiting) {
                content = const Center(child: CircularProgressIndicator());
              } else if (snap.hasError) {
                content = Center(
                  child: _StateCard(
                    icon: Icons.error_outline,
                    title: 'Erro ao carregar turmas',
                    subtitle: '${snap.error}',
                  ),
                );
              } else {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  content = const Center(
                    child: _StateCard(
                      icon: Icons.bookmark_border,
                      title: 'Você ainda não está matriculado em turmas',
                      subtitle: 'Quando for vinculado, elas aparecerão aqui.',
                    ),
                  );
                } else {
                  content = ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final cid = d.id;
                      final name = (d.data()['name'] ?? cid).toString();

                      return _Glass(
                        radius: 16,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)],
                              ),
                            ),
                            child: const Icon(Icons.class_, color: Colors.white),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('ID: $cid', style: const TextStyle(color: Colors.white70)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
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
                  );
                }
              }

              return Column(
                children: [
                  const SizedBox(height: kToolbarHeight + 6),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: _Glass(
                      radius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: const [
                          Icon(Icons.menu_book_outlined, color: Colors.white70),
                          SizedBox(width: 8),
                          Text(
                            pageTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 136,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
        child: SizedBox(
          width: 136,
          child: _BackPill(onTap: () => Navigator.maybePop(context)),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Sair',
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            }
          },
        ),
      ],
    );
  }
}

/* ========================= UI helpers (glass/fundo/botões) ========================= */

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _StateCard({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _Glass(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackPill extends StatelessWidget {
  final VoidCallback onTap;
  const _BackPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
      label: const Text('Voltar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(.10),
        side: const BorderSide(color: Colors.white24),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const _Glass({required this.child, this.padding, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF121022).withOpacity(.10),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(.10)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 16))],
          ),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/poliedro.png'),
              fit: BoxFit.cover,
            ),
            gradient: LinearGradient(
              colors: [const Color(0xFF0B091B).withOpacity(.88), const Color(0xFF0B091B).withOpacity(.88)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Center(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/images/iconePoliedro.png',
                width: _watermarkSize(context),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _watermarkSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 640) return (w * 1.15).clamp(420.0, 760.0);
    if (w < 1000) return (w * 0.82).clamp(520.0, 780.0);
    return (w * 0.55).clamp(700.0, 900.0);
  }
}
