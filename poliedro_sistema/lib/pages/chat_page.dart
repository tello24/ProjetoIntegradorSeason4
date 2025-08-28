import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String peerUid;      // UID do outro usuário
  final String? peerName;
  final String? peerEmail;
  final String? peerRa;      // RA do aluno (opcional)

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

    // carrega meu RA (se eu for aluno) e depois monta a stream
    FirebaseFirestore.instance.collection('users').doc(_myUid).get().then((doc) {
      _myRa = (doc.data()?['ra'] ?? '').toString().trim();
      _messagesStream = _buildQuery().snapshots();
      if (mounted) setState(() {});
    });
  }

  // -------- helper: OR progressivo (Filter.or requer >=2 args posicionais) -------
  Filter _orAll(List<Filter> fs) {
    if (fs.isEmpty) {
      // fallback impossível, mas evita crash em dev:
      return Filter('fromUid', isEqualTo: _myUid);
    }
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

    // Conversa por UID (sempre disponível)
    filters.add(Filter.and(
      Filter('fromUid', isEqualTo: _myUid),
      Filter('toUid', isEqualTo: widget.peerUid),
    ));
    filters.add(Filter.and(
      Filter('fromUid', isEqualTo: widget.peerUid),
      Filter('toUid', isEqualTo: _myUid),
    ));

    // Conversa por RA (se ambos tiverem RA configurado)
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

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'fromUid': _myUid,
        'toUid': widget.peerUid,
        'fromRa': _myRa,               // pode ser null
        'toRa': widget.peerRa,         // pode ser null
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
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

  @override
  Widget build(BuildContext context) {
    if (_messagesStream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_title())),
      body: Column(
        children: [
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
                      child: Text('Erro: ${snap.error}', textAlign: TextAlign.center),
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Sem mensagens ainda.'));
                }

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

                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 360),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(text, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text(
                              time,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: Theme.of(context).hintColor),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Escreva uma mensagem...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
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
        ],
      ),
    );
  }
}
