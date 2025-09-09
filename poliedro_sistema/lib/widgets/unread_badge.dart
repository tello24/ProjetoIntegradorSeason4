import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UnreadCounterBadge extends StatelessWidget {
  final String peerUid;
  const UnreadCounterBadge({super.key, required this.peerUid});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const SizedBox.shrink();

    // escuta users/{me} para pegar chatLastSeen.{peerUid}
    final meDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: meDocStream,
      builder: (context, meSnap) {
        if (!meSnap.hasData) return const SizedBox.shrink();
        final data = meSnap.data!.data() ?? {};
        final lastSeenMap = (data['chatLastSeen'] as Map?) ?? {};
        final lastSeen = lastSeenMap[peerUid]; // Timestamp? (ou null)

        Query<Map<String, dynamic>> q = FirebaseFirestore.instance
            .collection('messages')
            .where('fromUid', isEqualTo: peerUid)
            .where('toUid', isEqualTo: myUid);

        if (lastSeen is Timestamp) {
          q = q.where('createdAt', isGreaterThan: lastSeen);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: q.snapshots(),
          builder: (context, msgSnap) {
            if (!msgSnap.hasData) return const SizedBox.shrink();
            final count = msgSnap.data!.docs.length;
            if (count <= 0) return const SizedBox.shrink();
            return _Badge(count: count);
          },
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)],
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}
