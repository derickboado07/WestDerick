import 'dart:async';

import '../../providers/cart_provider.dart' show CartItem; // reuse item shape
import '../models/cart_participant.dart';
import '../models/cart_session.dart';
import '../models/split_payment.dart';
import 'realtime_channel.dart';

class CollabCartService {
  final RealTimeChannel channel;
  final String? wsUrl; // if null, treated as in-memory

  CollabCartService({required this.channel, this.wsUrl});

  CartSession? _session;
  StreamSubscription<Map<String, dynamic>>? _sub;

  CartSession? get session => _session;

  final _updates = StreamController<CartSession>.broadcast();
  Stream<CartSession> get updates => _updates.stream;

  Future<CartSession> createSession({
    required CartParticipant host,
    List<CartItem> initialItems = const [],
  }) async {
    final snapshot = _cartSnapshotFromItems(initialItems);
    _session = CartSession(
      participants: [host.copyWith(isHost: true)],
      hostParticipantId: host.id,
      cartSnapshot: snapshot,
    );
    await _attachChannel();
    _emitLocal({'type': 'session_created', 'session': _session!.toJson()});
    return _session!;
  }

  Future<CartSession> joinSession({
    required String sessionId,
    required CartParticipant participant,
  }) async {
    _session = CartSession(
      id: sessionId,
      participants: [participant],
      cartSnapshot: {},
    );
    await _attachChannel();
    await channel.send({'type': 'join', 'participant': participant.toJson()});
    return _session!;
  }

  Future<void> leaveSession(String participantId) async {
    if (_session == null) return;
    await channel.send({'type': 'leave', 'participantId': participantId});
  }

  Future<void> importItems(List<CartItem> items) async {
    if (_session == null) return;
    final snapshot = _cartSnapshotFromItems(items);
    _session = _session!.copyWith(cartSnapshot: snapshot);
    await channel.send({'type': 'cart_update', 'cartSnapshot': snapshot});
    _updates.add(_session!);
  }

  Future<void> updateSplitPlan(SplitPaymentPlan plan) async {
    if (_session == null) return;
    _session = _session!.copyWith(splitPlan: plan);
    await channel.send({'type': 'split_update', 'splitPlan': plan.toJson()});
    _updates.add(_session!);
  }

  Future<void> closeSession() async {
    if (_session == null) return;
    await channel.send({'type': 'session_closed'});
    await channel.close();
    _session = null;
  }

  Future<void> _attachChannel() async {
    await _sub?.cancel();
    final id = _session!.id;
    await channel.connect(wsUrl ?? 'in-memory://', sessionId: id);
    _sub = channel.messages.listen((message) {
      final type = message['type'];
      switch (type) {
        case 'session_created':
          _session = CartSession.fromJson(message['session'] as Map<String, dynamic>);
          break;
        case 'join':
          final p = CartParticipant.fromJson(message['participant'] as Map<String, dynamic>);
          final existing = _session!.participants.any((e) => e.id == p.id);
          if (!existing) {
            final list = [..._session!.participants, p];
            _session = _session!.copyWith(participants: list);
          }
          break;
        case 'leave':
          final id = message['participantId'] as String;
          final list = _session!.participants.where((e) => e.id != id).toList();
          _session = _session!.copyWith(participants: list);
          break;
        case 'cart_update':
          _session = _session!.copyWith(
              cartSnapshot: (message['cartSnapshot'] as Map).cast<String, dynamic>());
          break;
        case 'split_update':
          _session = _session!.copyWith(
              splitPlan: SplitPaymentPlan.fromJson(
                  (message['splitPlan'] as Map).cast<String, dynamic>()));
          break;
        case 'session_closed':
          _session = _session!.copyWith(isActive: false);
          break;
      }
      if (_session != null) _updates.add(_session!);
    });
  }

  void _emitLocal(Map<String, dynamic> message) {
    // In-memory bus needs us to echo messages
    channel.send(message);
  }

  static Map<String, dynamic> _cartSnapshotFromItems(List<CartItem> items) {
    return {
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
  }
}
