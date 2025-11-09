import 'package:uuid/uuid.dart';

class CartParticipant {
  final String id; // userId or guest id
  final String displayName;
  final bool isHost;
  // Optional running total for convenience on client
  final double contributedAmount;
  final bool hasPaid;
  final DateTime? paidAt;

  CartParticipant({
    String? id,
    required this.displayName,
    this.isHost = false,
    this.contributedAmount = 0.0,
    this.hasPaid = false,
    this.paidAt,
  }) : id = id ?? const Uuid().v4();

  CartParticipant copyWith({
    String? id,
    String? displayName,
    bool? isHost,
    double? contributedAmount,
    bool? hasPaid,
    DateTime? paidAt,
  }) => CartParticipant(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        isHost: isHost ?? this.isHost,
        contributedAmount: contributedAmount ?? this.contributedAmount,
        hasPaid: hasPaid ?? this.hasPaid,
        paidAt: paidAt ?? this.paidAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'isHost': isHost,
        'contributedAmount': contributedAmount,
    'hasPaid': hasPaid,
    'paidAt': paidAt?.toIso8601String(),
      };

  factory CartParticipant.fromJson(Map<String, dynamic> json) => CartParticipant(
        id: json['id'] as String?,
        displayName: json['displayName'] as String,
        isHost: (json['isHost'] as bool?) ?? false,
        contributedAmount: (json['contributedAmount'] as num?)?.toDouble() ?? 0.0,
    hasPaid: (json['hasPaid'] as bool?) ?? false,
    paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt'] as String) : null,
      );
}
