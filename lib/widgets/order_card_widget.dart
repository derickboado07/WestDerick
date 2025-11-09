import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderCardWidget extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const OrderCardWidget({super.key, required this.orderData});

  @override
  Widget build(BuildContext context) {
    final Timestamp? timestamp = orderData['createdAt'];
    final String formattedDate = timestamp != null
        ? DateFormat('MM/dd/yyyy - hh:mm a').format(timestamp.toDate())
        : 'Date not available';

    double totalPrice = 0.0;
    try {
      final raw = orderData['totalPrice'];
      if (raw is num) totalPrice = raw.toDouble();
      if (raw is String) totalPrice = double.tryParse(raw) ?? 0.0;
    } catch (_) {
      totalPrice = 0.0;
    }

    // Prefer saved itemCount; fall back to counting items list if present
    int itemCount = 0;
    final rawCount = orderData['itemCount'];
    if (rawCount is num) {
      itemCount = rawCount.toInt();
    } else if (orderData['items'] is List) {
      itemCount = (orderData['items'] as List).fold<int>(0, (acc, e) {
        try {
          final q = (e is Map && e['quantity'] is num) ? (e['quantity'] as num).toInt() : 1;
          return acc + q;
        } catch (_) {
          return acc + 1; // best effort
        }
      });
    }

    final status = (orderData['status'] ?? 'Pending').toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListTile(
          title: Text(
            'Total: ₱${totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Text('Items: $itemCount\nStatus: $status'),
          trailing: Text(
            formattedDate,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}
