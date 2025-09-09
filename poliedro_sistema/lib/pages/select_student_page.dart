import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart';

class SelectStudentPage extends StatefulWidget {
  const SelectStudentPage({super.key});
  @override
  State<SelectStudentPage> createState() => _SelectStudentPageState();
}

class _SelectStudentPageState extends State<SelectStudentPage> {
  String _query = '';
  late final String _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'aluno');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 136,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
          child: SizedBox(width: 136, child: _BackPill(onTap: () => Navigator.maybePop(context))),
        ),
        title: const Text('Selecionar aluno',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Bg(),
          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  decoration: _decDark('Buscar por nome ou RA...', icon: Icons.search),
                  style: const TextStyle(color: Colors.white),
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
                      return Center(
                        child: Text('Erro: ${snap.error}',
                            style: const TextStyle(color: Colors.white)),
                      );
                    }

                    final docs = snap.data?.docs ?? [];
                    final filtered = docs.where((d) {
                      final name = (d['name'] ?? '').toString().toLowerCase();
                      final ra = (d['ra'] ?? '').toString().toLowerCase();
                      return _query.isEmpty || name.contains(_query) || ra.contains(_query);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('Nenhum aluno encontrado',
                            style: TextStyle(color: Colors.white70)),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final d = filtered[i];
                        final uid = d.id;
                        final name = (d['name'] ?? 'Aluno').toString();
                        final ra = (d['ra'] ?? '').toString();
                        final email = (d['email'] ?? '').toString();

                        return _Glass(
                          radius: 16,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            leading: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)],
                                ),
                              ),
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text('$name · RA $ra',
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text('ID: $uid', style: const TextStyle(color: Colors.white70)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _UnreadBadge(myUid: _myUid, peerUid: uid),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right, color: Colors.white70),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    peerUid: uid,
                                    peerName: name,
                                    peerEmail: email,
                                    peerRa: ra,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ===== mesmos helpers do professor ===== */

class _UnreadBadge extends StatelessWidget {
  final String myUid;
  final String peerUid;
  const _UnreadBadge({required this.myUid, required this.peerUid});

  @override
  Widget build(BuildContext context) {
    final s = FirebaseFirestore.instance
        .collection('messages')
        .where('toUid', isEqualTo: myUid)
        .where('fromUid', isEqualTo: peerUid)
        .where('read', isEqualTo: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: s,
      builder: (_, snap) {
        final c = snap.data?.size ?? 0;
        if (c == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$c', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        );
      },
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
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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

InputDecoration _decDark(String hint, {IconData? icon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white60),
    prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
    filled: true,
    fillColor: Colors.white.withOpacity(.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white54),
    ),
  );
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
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
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
