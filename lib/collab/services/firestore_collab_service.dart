import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_participant.dart';
import '../models/cart_session.dart';
import '../models/split_payment.dart';

class FirestoreCollabService {
  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreCollabService({FirebaseFirestore? db, this.collectionPath = 'collab_sessions'})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessions => _db.collection(collectionPath);

  DocumentReference<Map<String, dynamic>> _sessionRef(String sessionId) => _sessions.doc(sessionId);

  CollectionReference<Map<String, dynamic>> _participantsRef(String sessionId) =>
      _sessionRef(sessionId).collection('participants');

  Future<void> createSession(CartSession session) async {
    final ref = _sessionRef(session.id);
    await ref.set({
      'id': session.id,
      'hostParticipantId': session.hostParticipantId,
      'cartSnapshot': session.cartSnapshot,
      'splitPlan': session.splitPlan?.toJson(),
      'isActive': session.isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final p in session.participants) {
      await _participantsRef(session.id).doc(p.id).set({
        'id': p.id,
        'displayName': p.displayName,
        'isHost': p.isHost,
        'contributedAmount': p.contributedAmount,
        'hasPaid': p.hasPaid,
        'paidAt': p.paidAt,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> joinSession(String sessionId, CartParticipant participant) async {
    await _participantsRef(sessionId).doc(participant.id).set({
      'id': participant.id,
      'displayName': participant.displayName,
      'isHost': participant.isHost,
      'contributedAmount': participant.contributedAmount,
      'hasPaid': participant.hasPaid,
      'paidAt': participant.paidAt,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> leaveSession(String sessionId, String participantId) async {
    await _participantsRef(sessionId).doc(participantId).delete();
  }

  Future<void> updateCartSnapshot(String sessionId, Map<String, dynamic> snapshot) async {
    await _sessionRef(sessionId).set({'cartSnapshot': snapshot}, SetOptions(merge: true));
  }

  Future<void> updateSplitPlan(String sessionId, SplitPaymentPlan plan) async {
    await _sessionRef(sessionId).set({'splitPlan': plan.toJson()}, SetOptions(merge: true));
  }

  Stream<CartSession> watchSession(String sessionId) {
    final sessionDocStream = _sessionRef(sessionId).snapshots();
    final participantsStream = _participantsRef(sessionId).snapshots();

    late StreamController<CartSession> controller;
    controller = StreamController<CartSession>.broadcast();

    Map<String, dynamic>? lastDocData;
    List<CartParticipant> lastParticipants = const [];

    void emitIfReady() {
      if (lastDocData == null) return;
      final data = lastDocData!;
      final session = CartSession(
        id: data['id'] as String? ?? sessionId,
        hostParticipantId: data['hostParticipantId'] as String?,
        participants: lastParticipants,
        cartSnapshot: (data['cartSnapshot'] as Map?)?.cast<String, dynamic>() ?? {},
        splitPlan: data['splitPlan'] == null
            ? null
            : SplitPaymentPlan.fromJson((data['splitPlan'] as Map).cast<String, dynamic>()),
        isActive: (data['isActive'] as bool?) ?? true,
        createdAt: DateTime.now(),
      );
      controller.add(session);
    }

    final sub1 = sessionDocStream.listen((doc) {
      lastDocData = doc.data();
      emitIfReady();
    });

    final sub2 = participantsStream.listen((snap) {
      lastParticipants = snap.docs
          .map((d) => CartParticipant.fromJson(d.data()))
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      emitIfReady();
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  Future<void> markParticipantPaid(String sessionId, String participantId, double amount) async {
    await _participantsRef(sessionId).doc(participantId).set({
      'contributedAmount': amount,
      'hasPaid': true,
      'paidAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Create a consolidated order in the global 'orders' collection for a fully-paid session
  /// and mark the session inactive. Returns the new orderId.
  Future<String> finalizeCollaborativeOrder({
    required CartSession session,
    required String createdByUserId,
  }) async {
    // Derive order fields from the session snapshot
    final snapshot = session.cartSnapshot;
    final List<dynamic> rawItems = (snapshot['items'] as List?) ?? const [];
    final double subtotal = (snapshot['subtotal'] as num?)?.toDouble() ?? 0.0;
    // Keep VAT logic consistent with CartProvider (12%)
    final double vat = subtotal * 0.12;
    final double totalPrice = subtotal + vat;
    final int itemCount = rawItems.fold<int>(0, (sum, it) => sum + ((it['quantity'] as num?)?.toInt() ?? 0));

    final items = rawItems.map((e) => {
          'id': e['id'],
          'name': e['name'],
          'price': (e['price'] as num?)?.toDouble() ?? 0.0,
          'quantity': (e['quantity'] as num?)?.toInt() ?? 0,
        }).toList();

    final participants = session.participants
        .map((p) => {
              'id': p.id,
              'displayName': p.displayName,
              'isHost': p.isHost,
              'contributedAmount': p.contributedAmount,
              'hasPaid': p.hasPaid,
              'paidAt': p.paidAt != null ? Timestamp.fromDate(p.paidAt!) : null,
            })
        .toList();

    final orderRef = await _db.collection('orders').add({
      'userId': createdByUserId, // attributed to the host/current user
      'items': items,
      'subtotal': subtotal,
      'vat': vat,
      'totalPrice': totalPrice,
      'itemCount': itemCount,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
      // collaborative metadata
      'isCollaborative': true,
      'collabSessionId': session.id,
      'participants': participants,
      'splitPlan': session.splitPlan?.toJson(),
    });

    // Soft-close the session
    await _sessionRef(session.id).set({'isActive': false, 'finalizedOrderId': orderRef.id}, SetOptions(merge: true));

    return orderRef.id;
  }
}
