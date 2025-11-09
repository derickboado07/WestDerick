import 'package:ecommerce_app/collab/models/split_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Equal split sums to total', () {
    const total = 300.0;
    final count = 3;
    final per = total / count;
    final shares = List.generate(
      count,
      (i) => SplitPaymentShare(participantId: 'p$i', amount: per, percentage: 100 / count),
    );
    final plan = SplitPaymentPlan(mode: SplitMode.percentage, shares: shares);
    final sum = plan.shares.fold<double>(0, (s, e) => s + e.amount);
    expect(sum, closeTo(total, 0.0001));
  });
}
