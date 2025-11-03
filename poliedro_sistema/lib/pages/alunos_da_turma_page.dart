// lib/pages/alunos_da_turma_page.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AlunosDaTurmaPage extends StatefulWidget {
  final String turmaId;
  final String nomeTurma;

  const AlunosDaTurmaPage({
    super.key,
    required this.turmaId,
    required this.nomeTurma,
  });

  @override
  State<AlunosDaTurmaPage> createState() => _AlunosDaTurmaPageState();
}

class _AlunosDaTurmaPageState extends State<AlunosDaTurmaPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _alunos = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchAlunos();
  }

  Future<void> _fetchAlunos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // RAs na subcoleção da turma
      final studentDocs = await _firestore
          .collection('classes')
          .doc(widget.turmaId)
          .collection('students')
          .get();

      final ras = studentDocs.docs.map((doc) => doc.id).toList();
      if (ras.isEmpty) {
        if (mounted) setState(() => _alunos = []);
        return;
      }

      // Busca nomes na coleção users por RA
      final usersQuery = await _firestore
          .collection('users')
          .where('ra', whereIn: ras)
          .get();

      final alunosData = usersQuery.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();

      if (mounted) setState(() => _alunos = alunosData);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar alunos: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- Adicionar por RA ----------
  Future<void> _addStudentByRa(String ra) async {
    final raTrimmed = ra.trim();
    if (!RegExp(r'^\d{7}$').hasMatch(raTrimmed)) {
      _showErrorSnackBar('RA inválido. Informe exatamente 7 dígitos numéricos.');
      return;
    }
    if (_alunos.any((aluno) => aluno['ra'] == raTrimmed)) {
      _showErrorSnackBar('Este aluno já está cadastrado na turma.');
      return;
    }

    try {
      final userQuery = await _firestore
          .collection('users')
          .where('ra', isEqualTo: raTrimmed)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showErrorSnackBar('Nenhum aluno encontrado com o RA informado.');
        return;
      }

      final batch = _firestore.batch();
      final classRef = _firestore.collection('classes').doc(widget.turmaId);

      // 1) subcoleção
      batch.set(classRef.collection('students').doc(raTrimmed), {
        'addedAt': FieldValue.serverTimestamp(),
        'ra': raTrimmed,
      });
      // 2) array no doc da turma
      batch.update(classRef, {
        'studentRAs': FieldValue.arrayUnion([raTrimmed]),
      });

      await batch.commit();

      if (mounted) Navigator.of(context).pop();
      _showSuccessSnackBar('Aluno adicionado com sucesso!');
      await _fetchAlunos();
    } on FirebaseException catch (e) {
      _showErrorSnackBar('Erro de banco de dados: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Ocorreu um erro inesperado: $e');
    }
  }

  // ---------- Remover ----------
  Future<void> _deleteStudent(String ra) async {
    try {
      final batch = _firestore.batch();
      final classRef = _firestore.collection('classes').doc(widget.turmaId);

      // 1) remove da subcoleção
      batch.delete(classRef.collection('students').doc(ra));
      // 2) remove do array
      batch.update(classRef, {
        'studentRAs': FieldValue.arrayRemove([ra]),
      });

      await batch.commit();

      setState(() {
        _alunos.removeWhere((aluno) => aluno['ra'] == ra);
      });
      _showSuccessSnackBar('Aluno removido da turma.');
    } on FirebaseException catch (e) {
      _showErrorSnackBar('Erro de banco de dados: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Ocorreu um erro inesperado ao remover: $e');
    }
  }

  // ---------- Diálogo com AUTOCOMPLETE ----------
  void _showAddStudentDialog() {
    final raController = TextEditingController();

    List<Map<String, dynamic>> suggestions = [];
    bool searching = false;
    Timer? debouncer;

    Future<void> runSearch(String prefix) async {
      debouncer?.cancel();
      debouncer = Timer(const Duration(milliseconds: 250), () async {
        final q = prefix.trim();
        if (q.isEmpty) {
          suggestions = [];
          if (mounted) setState(() {}); 
          return;
        }
        try {
          final snap = await _firestore
              .collection('users')
              .where('ra', isGreaterThanOrEqualTo: q)
              .where('ra', isLessThan: '$q\uf8ff')
              .limit(10)
              .get();

          suggestions = snap.docs.map((d) {
            final data = d.data();
            return {
              'name': (data['name'] ?? '').toString(),
              'ra': (data['ra'] ?? '').toString(),
            };
          }).toList();
        } catch (_) {
          suggestions = [];
        }
        searching = false;
      });
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            Future<void> onChanged(String v) async {
              setDlg(() => searching = true);
              await runSearch(v);
              if (ctx.mounted) setDlg(() {});
            }

            return AlertDialog(
              title: const Text('Adicionar Aluno por RA'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: raController,
                      decoration: const InputDecoration(
                        labelText: 'RA do Aluno (7 dígitos)',
                        hintText: 'Ex.: 3123456',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 7,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => onChanged(v),
                      onSubmitted: (v) => _addStudentByRa(v),
                    ),
                    const SizedBox(height: 8),
                    // Lista de sugestões
                    if (searching) const LinearProgressIndicator(minHeight: 2),
                    if (suggestions.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: Material(
                          color: Colors.transparent,
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: suggestions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final s = suggestions[i];
                              final sName = (s['name'] as String?) ?? '';
                              final sRa = (s['ra'] as String?) ?? '';
                              return ListTile(
                                dense: true,
                                visualDensity:
                                    const VisualDensity(vertical: -2),
                                leading: const Icon(Icons.person_outline),
                                title: Text(
                                  sName.isEmpty ? '(Sem nome)' : sName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('RA: $sRa'),
                                trailing: IconButton(
                                  tooltip: 'Adicionar este RA',
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _addStudentByRa(sRa),
                                ),
                                onTap: () {
                                  raController.text = sRa;
                                  raController.selection =
                                      TextSelection.collapsed(
                                          offset: sRa.length);
                                  setDlg(() {});
                                },
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => _addStudentByRa(raController.text),
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => debouncer?.cancel());
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 140,
        leading: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: _BackPill(onTap: () => Navigator.maybePop(context)),
          ),
        ),

        title: null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Aluno'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Bg(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: kToolbarHeight - 8),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Alunos de ${widget.nomeTurma}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _alunos.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum aluno cadastrado nesta turma.',
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                              itemCount: _alunos.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final aluno = _alunos[index];
                                final first = (aluno['name'] ?? 'A').toString();
                                final initial = first.isNotEmpty
                                    ? first.characters.first.toUpperCase()
                                    : 'A';

                                return _Glass(
                                  radius: 16,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blueGrey[700],
                                      child: Text(
                                        initial,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Text(
                                      aluno['name'] ?? 'Nome não encontrado',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      'RA: ${aluno['ra'] ?? 'N/A'}',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      tooltip: 'Remover aluno da turma',
                                      onPressed: () => _deleteStudent(aluno['ra']),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ========================= UI ========================= */

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
              BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 16))
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
          colors: [const Color(0xFF0B091B).withOpacity(.88), const Color(0xFF0B091B).withOpacity(.88)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: Colors.white,
        size: 18,
      ),
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
    );
  }
}
