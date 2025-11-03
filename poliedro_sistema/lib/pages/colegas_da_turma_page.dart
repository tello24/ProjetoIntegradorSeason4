// lib/pages/colegas_da_turma_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ColegasDaTurmaPage extends StatefulWidget {
  final String turmaId;
  final String nomeTurma;

  const ColegasDaTurmaPage({
    super.key,
    required this.turmaId,
    required this.nomeTurma,
  });

  @override
  State<ColegasDaTurmaPage> createState() => _ColegasDaTurmaPageState();
}

class _ColegasDaTurmaPageState extends State<ColegasDaTurmaPage> {
  bool _isLoading = true;
  List<Map<String, String>> _colegas = [];

  @override
  void initState() {
    super.initState();
    _fetchColegas();
  }

  Future<void> _fetchColegas() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.turmaId)
          .collection('students')
          .get();

      final List<String> ras = studentsSnapshot.docs
          .map((doc) => doc.id)
          .toList();

      if (ras.isEmpty) {
        if (mounted)
          setState(() {
            _colegas = [];
            _isLoading = false;
          });
        return;
      }

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('ra', whereIn: ras)
          .get();

      final List<Map<String, String>> colegasList = [];
      for (var userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        colegasList.add({
          'name': (data['name'] ?? 'Nome não encontrado').toString(),
          'ra': (data['ra'] ?? 'RA não encontrado').toString(),
        });
      }

      colegasList.sort((a, b) => a['name']!.compareTo(b['name']!));

      if (mounted) {
        setState(() {
          _colegas = colegasList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao buscar colegas: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Colegas de "${widget.nomeTurma}"',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Bg(),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _colegas.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum aluno cadastrado nesta turma.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      kToolbarHeight / 2,
                      12,
                      16,
                    ),
                    itemCount: _colegas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final colega = _colegas[index];
                      return _Glass(
                        radius: 16,
                        child: ListTile(
                          leading: const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                          ),
                          title: Text(
                            colega['name']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'RA: ${colega['ra']}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// UI Helpers 
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
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
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
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/poliedro.png'),
          fit: BoxFit.cover,
        ),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0B091B).withOpacity(.88),
            const Color(0xFF0B091B).withOpacity(.88),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
