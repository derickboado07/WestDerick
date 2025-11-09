import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: FutureBuilder<DocumentSnapshot>(
        future: firestore.collection('orders').doc(orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'Pending').toString();
          final totalRaw = data['totalPrice'];
          double total = 0.0;
          if (totalRaw is num) total = totalRaw.toDouble();
          if (totalRaw is String) total = double.tryParse(totalRaw) ?? 0.0;

          final ts = data['createdAt'];
          String dateStr = '-';
          if (ts is Timestamp) {
            dateStr = DateFormat('MM/dd/yy hh:mm a').format(ts.toDate());
          }

          final items = (data['items'] as List?) ?? const [];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Text('Order ID: $orderId', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Status: $status'),
                const SizedBox(height: 4),
                Text('Total: ₱${total.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                Text('Placed: $dateStr'),
                const Divider(height: 24),
                const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Text('No items available')
                else
                  ...items.map((e) {
                    if (e is Map<String, dynamic>) {
                      final name = (e['name'] ?? 'Item').toString();
                      final qty = (e['quantity'] is num) ? (e['quantity'] as num).toInt() : 1;
                      final priceRaw = e['price'];
                      double p = 0.0;
                      if (priceRaw is num) p = priceRaw.toDouble();
                      if (priceRaw is String) p = double.tryParse(priceRaw) ?? 0.0;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(name),
                        subtitle: Text('Qty: $qty  •  ₱${p.toStringAsFixed(2)}'),
                      );
                    }
                    return const SizedBox.shrink();
                  }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
