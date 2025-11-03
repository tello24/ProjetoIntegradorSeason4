import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String peerUid;
  final String? peerName;
  final String? peerEmail;
  final String? peerRa;

  const ChatPage({
    super.key,
    required this.peerUid,
    this.peerName,
    this.peerEmail,
    this.peerRa,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final String _myUid;
  String? _myRa;

  final _msgCtrl = TextEditingController();
  final _listCtrl = ScrollController();

  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  bool _sending = false;

  DateTime? _lastMarkRun;

  @override
  void initState() {
    super.initState();

    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      });
      return;
    }
    _myUid = u.uid;

    FirebaseFirestore.instance.collection('users').doc(_myUid).get().then((doc) {
      _myRa = (doc.data()?['ra'] ?? '').toString().trim();
      _messagesStream = _buildQuery().snapshots();
      if (mounted) setState(() {});
      
      WidgetsBinding.instance.addPostFrameCallback((_) => _markIncomingAsRead());
    });
  }

  // --------- helpers de consulta ----------
  Filter _orAll(List<Filter> fs) {
    if (fs.isEmpty) return Filter('fromUid', isEqualTo: _myUid);
    if (fs.length == 1) return fs.first;
    var acc = Filter.or(fs[0], fs[1]);
    for (var i = 2; i < fs.length; i++) {
      acc = Filter.or(acc, fs[i]);
    }
    return acc;
  }

  Query<Map<String, dynamic>> _buildQuery() {
    final coll = FirebaseFirestore.instance.collection('messages');
    final List<Filter> filters = [];

    // por UID
    filters.add(Filter.and(
      Filter('fromUid', isEqualTo: _myUid),
      Filter('toUid', isEqualTo: widget.peerUid),
    ));
    filters.add(Filter.and(
      Filter('fromUid', isEqualTo: widget.peerUid),
      Filter('toUid', isEqualTo: _myUid),
    ));

    // por RA 
    if ((_myRa != null && _myRa!.isNotEmpty) &&
        (widget.peerRa != null && widget.peerRa!.isNotEmpty)) {
      filters.add(Filter.and(
        Filter('fromRa', isEqualTo: _myRa),
        Filter('toRa', isEqualTo: widget.peerRa),
      ));
      filters.add(Filter.and(
        Filter('fromRa', isEqualTo: widget.peerRa),
        Filter('toRa', isEqualTo: _myRa),
      ));
    }

    final whereFilter = _orAll(filters);
    return coll.where(whereFilter).orderBy('createdAt', descending: true);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  // --------- marcar recebidas como lidas ----------
  Future<void> _markIncomingAsRead() async {
    final now = DateTime.now();
    if (_lastMarkRun != null &&
        now.difference(_lastMarkRun!) < const Duration(seconds: 1)) {
      return;
    }
    _lastMarkRun = now;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Conversa por UID
      final qUid = FirebaseFirestore.instance
          .collection('messages')
          .where('fromUid', isEqualTo: widget.peerUid)
          .where('toUid', isEqualTo: _myUid)
          .where('read', isEqualTo: false)
          .limit(500);
      final sUid = await qUid.get();
      for (final doc in sUid.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      // Conversa por RA 
      if ((_myRa?.isNotEmpty ?? false) && (widget.peerRa?.isNotEmpty ?? false)) {
        final qRa = FirebaseFirestore.instance
            .collection('messages')
            .where('fromRa', isEqualTo: widget.peerRa)
            .where('toRa', isEqualTo: _myRa)
            .where('read', isEqualTo: false)
            .limit(500);
        final sRa = await qRa.get();
        for (final doc in sRa.docs) {
          batch.update(doc.reference, {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (_) {
    }
  }

  // --------- envio ----------
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'fromUid': _myUid,
        'toUid': widget.peerUid,
        'fromRa': _myRa,
        'toRa': widget.peerRa,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false, 
      });

      _msgCtrl.clear();

      await Future.delayed(const Duration(milliseconds: 50));
      if (_listCtrl.hasClients) {
        _listCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } on FirebaseException catch (e) {
      _toast('Falha ao enviar: ${e.code} — ${e.message}');
    } catch (e) {
      _toast('Falha ao enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _title() {
    final name = (widget.peerName ?? '').trim();
    final email = (widget.peerEmail ?? '').trim();
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    if ((widget.peerRa ?? '').isNotEmpty) return 'RA ${widget.peerRa}';
    return 'Conversa';
  }

  String _fmtTime(Timestamp? ts) {
    if (ts == null) return '--:--';
    final dt = ts.toDate();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _fmtDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$month/$year';
  }

  // --------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (_messagesStream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
        title: Text(
          _title(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
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

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Erro: ${snap.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }

                    // marca como lidas quando dados chegam
                    if (snap.hasData) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _markIncomingAsRead());
                    }

                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Sem mensagens ainda.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    String lastDate = '';
                    return ListView.builder(
                      controller: _listCtrl,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data();
                        final mine = (d['fromUid'] ?? '') == _myUid;
                        final text = (d['text'] ?? '').toString();
                        final time = _fmtTime(d['createdAt'] as Timestamp?);
                        final date = _fmtDate(d['createdAt'] as Timestamp?);
                        final read = (d['read'] ?? false) == true;

                        final isNewDate = date != lastDate;
                        lastDate = date;

                        return Column(
                          crossAxisAlignment:
                              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (isNewDate && date.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Center(child: _DatePill(text: date)),
                              ),
                            Align(
                              alignment:
                                  mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: _MessageBubble(
                                mine: mine,
                                text: text,
                                time: time,
                                read: read, 
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: _Glass(
                    radius: 16,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            minLines: 1,
                            maxLines: 4,
                            style: const TextStyle(color: Colors.white),
                            decoration: _decDark('Escreva uma mensagem...'),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _sending ? null : _sendMessage,
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Enviar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ========================= UI ========================= */

class _MessageBubble extends StatelessWidget {
  final bool mine;
  final String text;
  final String time;
  final bool read; 
  const _MessageBubble({
    required this.mine,
    required this.text,
    required this.time,
    required this.read,
  });

  @override
  Widget build(BuildContext context) {
    final Color? bg = mine ? null : const Color(0xFF121022).withOpacity(.10);
    final Gradient? gradient =
        mine ? const LinearGradient(colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)]) : null;

    final Color txtColor = Colors.white;
    final Color timeColor = Colors.white70;

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 6),
          bottomRight: Radius.circular(mine ? 6 : 16),
        ),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(color: txtColor, height: 1.25, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(time, style: TextStyle(color: timeColor, fontSize: 11)),
              if (mine) ...[
                const SizedBox(width: 6),
                Icon(
                  read ? Icons.done_all_rounded : Icons.check_rounded,
                  size: 14,
                  color: read ? Colors.white : Colors.white70,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  final String text;
  const _DatePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
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

InputDecoration _decDark(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white60),
    filled: true,
    fillColor: Colors.white.withOpacity(.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
