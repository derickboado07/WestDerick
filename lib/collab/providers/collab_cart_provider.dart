import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../providers/cart_provider.dart' show CartItem;
import '../models/cart_participant.dart';
import '../models/cart_session.dart';
import '../models/split_payment.dart';
import '../services/firestore_collab_service.dart';

class CollabCartProvider extends ChangeNotifier {
  final FirestoreCollabService service;

  CollabCartProvider({required this.service});

  CartSession? _session;
  StreamSubscription<CartSession>? _sub;
  bool _busy = false;
  String? _error;
  String? _myParticipantId; // track current participant for leave

  CartSession? get session => _session;
  bool get isBusy => _busy;
  String? get error => _error;
  String? get myParticipantId => _myParticipantId;

  Future<void> createSession({required String displayName}) async {
    _busy = true; _error = null; notifyListeners();
    try {
      final host = CartParticipant(displayName: displayName, isHost: true);
      // create a local shell session, then persist and start watching
      final s = CartSession(participants: [host], cartSnapshot: {}, hostParticipantId: host.id);
      await service.createSession(s);
      _myParticipantId = host.id;
      _listenUpdates(s.id);
    } catch (e) {
      _error = '$e';
    } finally {
      _busy = false; notifyListeners();
    }
  }

  Future<void> joinSession({required String sessionId, required String displayName}) async {
    _busy = true; _error = null; notifyListeners();
    try {
      final me = CartParticipant(displayName: displayName);
      await service.joinSession(sessionId, me);
      _myParticipantId = me.id;
      _listenUpdates(sessionId);
    } catch (e) {
      _error = '$e';
    } finally {
      _busy = false; notifyListeners();
    }
  }

  Future<void> importItems(List<CartItem> items) async {
    if (_session == null) return;
    final snapshot = {
      'items': items
          .map((e) => {
                'id': e.id,
                'name': e.name,
                'price': e.price,
                'quantity': e.quantity,
              })
          .toList(),
      'subtotal': items.fold<double>(0, (sum, it) => sum + it.price * it.quantity),
    };
    await service.updateCartSnapshot(_session!.id, snapshot);
  }

  Future<void> setEqualSplit() async {
    if (_session == null) return;
    final total = (_session!.cartSnapshot['subtotal'] as num?)?.toDouble() ?? 0.0;
    final parts = _session!.participants;
    final map = _centSafeEqualSplit(total, parts);
    final shares = parts
        .map((p) => SplitPaymentShare(
              participantId: p.id,
              amount: map[p.id] ?? 0,
              percentage: parts.isEmpty ? 0 : (map[p.id]! / total) * 100,
            ))
        .toList();
    await service.updateSplitPlan(_session!.id, SplitPaymentPlan(mode: SplitMode.percentage, shares: shares));
  }

  Future<void> setCustomSplit(List<SplitPaymentShare> shares) async {
    if (_session == null) return;
    await service.updateSplitPlan(_session!.id, SplitPaymentPlan(mode: SplitMode.custom, shares: shares));
  }

  void _listenUpdates(String sessionId) {
    _sub?.cancel();
    _sub = service.watchSession(sessionId).listen((s) { _session = s; notifyListeners(); });
  }

  Future<void> leaveSession() async {
    if (_session == null || _myParticipantId == null) return;
    try {
      await service.leaveSession(_session!.id, _myParticipantId!);
    } catch (e) {
      _error = '$e';
    } finally {
      await _sub?.cancel();
      _sub = null;
      _session = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Map<String, double> _centSafeEqualSplit(double totalAmount, List<CartParticipant> participants) {
    final count = participants.length;
    if (count == 0) return {};
    final totalCents = (totalAmount * 100).round();
    final base = totalCents ~/ count;
    var remainder = totalCents - (base * count);
    final result = <String, double>{};
    for (var i = 0; i < count; i++) {
      final add = remainder > 0 ? 1 : 0;
      if (remainder > 0) remainder--;
      final cents = base + add;
      result[participants[i].id] = cents / 100.0;
    }
    return result;
  }
}
