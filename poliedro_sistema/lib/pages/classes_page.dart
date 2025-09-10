// lib/pages/classes_page.dart
import 'dart:ui' as ui; // para BackdropFilter.blur
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});
  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final _nameCtrl = TextEditingController();
  late final String _uid;
  late final String _email;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
      });
      return;
    }
    _uid = u.uid;
    _email = u.email ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // -------------------- CRUD TURMA --------------------

  Future<void> _createClass() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Informe o nome da turma.');
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('classes').add({
        'name': name,
        'ownerUid': _uid, // ✅ obrigatório nas regras
        'ownerEmail': _email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameCtrl.clear();
      _snack('Turma "$name" criada!');
    } on FirebaseException catch (e) {
      _snack('Falha: ${e.code} — ${e.message}');
    } catch (e) {
      _snack('Erro: $e');
    }
  }

  Future<void> _editName(DocumentReference ref, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF151331),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Renomear turma', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: _decDark('Nome'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              try {
                await ref.update({'name': ctrl.text.trim()});
                if (mounted) Navigator.pop(context);
                _snack('Turma atualizada!');
              } on FirebaseException catch (e) {
                _snack('Falha: ${e.code} — ${e.message}');
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClass(DocumentReference ref) async {
    try {
      await ref.delete(); // regras permitem se você for o dono
      _snack('Turma excluída.');
    } on FirebaseException catch (e) {
      _snack('Erro ao excluir: ${e.code} — ${e.message}');
    }
  }

  // -------------------- GERENCIAR RAs --------------------

  Future<void> _manageStudents(String classId) async {
    final raCtrl = TextEditingController();

    // RAs atuais da turma
    final current = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('students')
        .get();
    final ras = current.docs.map((d) => d.id).toList()..sort();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        // Estado local do diálogo (fora do StatefulBuilder, para persistir entre rebuilds do builder)
        List<String> suggestions = [];
        Timer? deb;

        // Fallback: baixa um lote de users e filtra por prefixo no cliente — retorna lista.
        Future<List<String>> _fallbackPrefix(String prefix) async {
          try {
            final snap2 = await FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'aluno')
                .limit(80) // lote pequeno
                .get();

            final lp = prefix.toLowerCase();
            final list2 = snap2.docs
                .map((d) => (d.data()['ra'] ?? '').toString())
                .where((ra) {
                  final s = ra.toLowerCase();
                  return s.isNotEmpty && s.startsWith(lp) && !ras.contains(ra);
                })
                .toSet()
                .toList()
              ..sort();

            return list2;
          } catch (_) {
            return <String>[];
          }
        }

        // Autocomplete principal: tenta índice (role + orderBy('ra')); se vazio/erro -> fallback.
        Future<void> _lookup(
          String prefix,
          void Function(void Function()) setDlg,
        ) async {
          final p = prefix.trim();

          // zera sugestões assim que começa a digitar
          setDlg(() => suggestions = []);
          if (p.isEmpty) return;

          // debounce
          deb?.cancel();
          deb = Timer(const Duration(milliseconds: 220), () async {
            try {
              final snap = await FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'aluno')
                  .orderBy('ra')
                  .startAt([p])
                  .endAt([p + '\uf8ff'])
                  .limit(10)
                  .get();

              final list = snap.docs
                  .map((d) => (d.data()['ra'] ?? '').toString())
                  .where((ra) => ra.isNotEmpty && !ras.contains(ra))
                  .toSet()
                  .toList()
                ..sort();

              if (dialogCtx.mounted) {
                setDlg(() => suggestions = list);
              }

              if (list.isEmpty) {
                final list2 = await _fallbackPrefix(p);
                if (dialogCtx.mounted) {
                  setDlg(() => suggestions = list2);
                }
              }
            } catch (_) {
              // Sem índice tipos mistos -> fallback
              final list2 = await _fallbackPrefix(p);
              if (dialogCtx.mounted) {
                setDlg(() => suggestions = list2);
                if (list2.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Usando busca simples. Crie o índice composto (users: role Asc + ra Asc) para acelerar.',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            }
          });
        }

        void _disposeDebounce() {
          deb?.cancel();
          deb = null;
        }

        return StatefulBuilder(
          builder: (ctx, setDlg) => WillPopScope(
            onWillPop: () async {
              _disposeDebounce();
              return true;
            },
            child: AlertDialog(
              backgroundColor: const Color(0xFF151331),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Alunos da turma (RAs)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Campo RA + autocomplete por prefixo
                  TextField(
                    controller: raCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _decDark('Adicionar RA (7 dígitos)', icon: Icons.badge_outlined),
                    onChanged: (v) => _lookup(v, setDlg),
                    onSubmitted: (_) async => _addRa(classId, raCtrl, ras, setDlg),
                  ),

                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in suggestions)
                            GestureDetector(
                              onTap: () {
                                raCtrl.text = s;
                                setDlg(() => suggestions = []);
                              },
                              child: _RaSuggestionChip(text: s),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // RAs já cadastrados
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ra in ras)
                          _RaChip(
                            text: ra,
                            onDelete: () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('classes')
                                    .doc(classId)
                                    .collection('students')
                                    .doc(ra)
                                    .delete();
                                setDlg(() => ras.remove(ra));
                                _snack('RA $ra removido.');
                              } on FirebaseException catch (e) {
                                _snack('Falha: ${e.code} — ${e.message}');
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  if (ras.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Nenhum RA cadastrado ainda.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                TextButton(
                  onPressed: () {
                    _disposeDebounce();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Fechar'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Adicionar RA'),
                  onPressed: () async => _addRa(classId, raCtrl, ras, setDlg),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addRa(
    String classId,
    TextEditingController raCtrl,
    List<String> ras,
    void Function(void Function()) setDlg,
  ) async {
    final ra = raCtrl.text.trim();
    if (!RegExp(r'^\d{7}$').hasMatch(ra)) {
      _snack('RA inválido. Use exatamente 7 dígitos.');
      return;
    }
    try {
      final classRef =
          FirebaseFirestore.instance.collection('classes').doc(classId);

      // subcoleção: classes/{classId}/students/{ra}
      await classRef
          .collection('students')
          .doc(ra)
          .set({'addedAt': FieldValue.serverTimestamp(), 'ra': ra},
              SetOptions(merge: true));

      // array studentRAs na turma (útil para queries do aluno)
      await classRef.update({'studentRAs': FieldValue.arrayUnion([ra])});

      setDlg(() {
        if (!ras.contains(ra)) ras.add(ra);
        ras.sort();
        raCtrl.clear();
      });
      _snack('RA $ra adicionado!');
    } on FirebaseException catch (e) {
      _snack('Falha: ${e.code} — ${e.message}');
    }
  }

  // -------------------- BUILD --------------------

  @override
  Widget build(BuildContext context) {
    final uidShort = _uid.length > 8 ? '${_uid.substring(0, 6)}…' : _uid;

    final stream = FirebaseFirestore.instance
        .collection('classes')
        .where('ownerUid', isEqualTo: _uid)
        .orderBy('name')
        .snapshots();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              }
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Bg(),

          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 6),

              // Header com usuário
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: _Glass(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Logado: $_email  (uid: $uidShort)',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Criar turma
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decDark('Nome da turma (ex.: 3ºB Matemática)',
                            icon: Icons.class_outlined),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _createClass,
                      icon: const Icon(Icons.add),
                      label: const Text('Criar'),
                    ),
                  ],
                ),
              ),

              // Lista de turmas
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Erro: ${snap.error}',
                              style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma turma ainda.',
                            style: TextStyle(color: Colors.white70)),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final data = d.data();
                        final name = (data['name'] ?? '').toString();

                        return _Glass(
                          radius: 16,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)],
                                ),
                              ),
                              child:
                                  const Icon(Icons.folder_open, color: Colors.white),
                            ),
                            title: Text(name.isEmpty ? '(sem nome)' : name,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text('id: ${d.id}',
                                style: const TextStyle(color: Colors.white54)),
                            onTap: () => _manageStudents(d.id),
                            trailing: PopupMenuButton<String>(
                              color: const Color(0xFF1A1830),
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 6,
                              offset: const Offset(0, 8),
                              icon: const Icon(Icons.more_vert, color: Colors.white70),
                              onSelected: (v) async {
                                if (v == 'rename') {
                                  await _editName(d.reference, name);
                                } else if (v == 'addra') {
                                  await _manageStudents(d.id);
                                } else if (v == 'delete') {
                                  await _deleteClass(d.reference);
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: _MenuTile(
                                      icon: Icons.edit_outlined, label: 'Renomear'),
                                ),
                                PopupMenuItem(
                                  value: 'addra',
                                  child: _MenuTile(
                                      icon: Icons.person_add_alt_1,
                                      label: 'Adicionar RA'),
                                ),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: _MenuTile(
                                    icon: Icons.delete_outline,
                                    label: 'Excluir',
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
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

  // ---------- helpers UI ----------

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
}

/* ========================= UI pieces ========================= */

class _BackPill extends StatelessWidget {
  final VoidCallback onTap;
  const _BackPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon:
          const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
      label: const Text('Voltar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(.10),
        side: const BorderSide(color: Colors.white24),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

class _RaChip extends StatelessWidget {
  final String text;
  final VoidCallback onDelete;
  const _RaChip({required this.text, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text,
            style:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onDelete,
          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
        ),
      ]),
    );
  }
}

class _RaSuggestionChip extends StatelessWidget {
  final String text;
  const _RaSuggestionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Text(
          text,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuTile({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Row(
      children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
        ),
      ],
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
              colors: [
                const Color(0xFF0B091B).withOpacity(.88),
                const Color(0xFF0B091B).withOpacity(.88)
              ],
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
