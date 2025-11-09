enum SplitMode { percentage, items, custom }

class SplitPaymentShare {
  final String participantId;
  final double amount; // absolute currency amount after calculation
  final double? percentage; // optional if mode == percentage
  final List<String>? itemIds; // optional if mode == items

  const SplitPaymentShare({
    required this.participantId,
    required this.amount,
    this.percentage,
    this.itemIds,
  });

  Map<String, dynamic> toJson() => {
        'participantId': participantId,
        'amount': amount,
        'percentage': percentage,
        'itemIds': itemIds,
      };

  factory SplitPaymentShare.fromJson(Map<String, dynamic> json) => SplitPaymentShare(
        participantId: json['participantId'] as String,
        amount: (json['amount'] as num).toDouble(),
        percentage: (json['percentage'] as num?)?.toDouble(),
        itemIds: (json['itemIds'] as List?)?.map((e) => e as String).toList(),
      );
}

class SplitPaymentPlan {
  final SplitMode mode;
  final List<SplitPaymentShare> shares; // sum(amount) == cart total
  final DateTime createdAt;

  SplitPaymentPlan({
    required this.mode,
    required this.shares,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'shares': shares.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory SplitPaymentPlan.fromJson(Map<String, dynamic> json) => SplitPaymentPlan(
        mode: SplitMode.values.firstWhere((m) => m.name == json['mode']),
        shares: (json['shares'] as List).map((e) => SplitPaymentShare.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
