import 'cart_participant.dart';
import 'split_payment.dart';
import 'package:uuid/uuid.dart';

class CartSession {
  final String id;
  final String? hostParticipantId; // convenience pointer
  final List<CartParticipant> participants;
  final Map<String, dynamic> cartSnapshot; // minimal cart representation
  final SplitPaymentPlan? splitPlan;
  final bool isActive;
  final DateTime createdAt;

  CartSession({
    String? id,
    required this.participants,
    required this.cartSnapshot,
    this.splitPlan,
    this.hostParticipantId,
    this.isActive = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  CartSession copyWith({
    String? id,
    String? hostParticipantId,
    List<CartParticipant>? participants,
    Map<String, dynamic>? cartSnapshot,
    SplitPaymentPlan? splitPlan,
    bool? isActive,
    DateTime? createdAt,
  }) => CartSession(
        id: id ?? this.id,
        hostParticipantId: hostParticipantId ?? this.hostParticipantId,
        participants: participants ?? this.participants,
        cartSnapshot: cartSnapshot ?? this.cartSnapshot,
        splitPlan: splitPlan ?? this.splitPlan,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostParticipantId': hostParticipantId,
        'participants': participants.map((p) => p.toJson()).toList(),
        'cartSnapshot': cartSnapshot,
        'splitPlan': splitPlan?.toJson(),
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CartSession.fromJson(Map<String, dynamic> json) => CartSession(
        id: json['id'] as String?,
        hostParticipantId: json['hostParticipantId'] as String?,
        participants: (json['participants'] as List?)
                ?.map((e) => CartParticipant.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        cartSnapshot: (json['cartSnapshot'] as Map?)?.cast<String, dynamic>() ?? {},
        splitPlan: json['splitPlan'] == null
            ? null
            : SplitPaymentPlan.fromJson(json['splitPlan'] as Map<String, dynamic>),
        isActive: (json['isActive'] as bool?) ?? true,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
