import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  // 1. Get an instance of Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 2. This is the function that updates the status in Firestore
  Future<void> _updateOrderStatus(String orderId, String newStatus, String userId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
      });
      // Create a notification for the user about this update
      try {
        // Use a client timestamp so the notification is immediately queryable
        // and visible in client-side queries. Also write a server timestamp
        // for authoritative ordering when available.
        await _firestore.collection('notifications').add({
          'userId': userId,
          'title': 'Order Status Updated',
          'body': 'Your order ($orderId) has been updated to "${newStatus}".',
          'orderId': orderId,
          'createdAt': Timestamp.now(), // client timestamp for immediate visibility
          'createdAtServer': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      } catch (e) {
        // Non-fatal: notification creation failed
        debugPrint('Failed to create notification: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  // 4. This function shows the update dialog
  void _showStatusDialog(String orderId, String currentStatus, String userId) {
    showDialog(
      context: context,
      builder: (context) {
        // 5. A list of all possible statuses
        const statuses = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];

        return AlertDialog(
          title: const Text('Update Order Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: statuses.map((status) {
                return ListTile(
                title: Text(status),
                trailing: currentStatus == status ? const Icon(Icons.check) : null,
                onTap: () {
                  _updateOrderStatus(orderId, status, userId);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
      ),
      // 1. Use a StreamBuilder to get all orders
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 3. Handle all states: loading, error, empty
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final orderData = order.data() as Map<String, dynamic>;

              // 5. Format the date
              final Timestamp? timestamp = orderData['createdAt'];
              final String formattedDate = timestamp != null
                  ? DateFormat('MM/dd/yyyy hh:mm a').format(timestamp.toDate())
                  : '-';

              // 6. Get the current status
              final String status = (orderData['status'] ?? 'Pending').toString();

              // Parse totalPrice defensively
              double totalPrice = 0.0;
              try {
                final raw = orderData['totalPrice'];
                if (raw is num) totalPrice = raw.toDouble();
                if (raw is String) totalPrice = double.tryParse(raw) ?? 0.0;
              } catch (_) {
                totalPrice = 0.0;
              }

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(
                    'Order ID: ${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  subtitle: Text(
                    'User: ${orderData['userId']}\n'
                    'Total: ₱${totalPrice.toStringAsFixed(2)} | Date: $formattedDate',
                  ),
                  isThreeLine: true,
                  trailing: Chip(
                    label: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: status == 'Pending'
                        ? Colors.orange
                        : status == 'Processing'
                            ? Colors.blue
                            : status == 'Shipped'
                                ? Colors.deepPurple
                                : status == 'Delivered'
                                    ? Colors.green
                                    : Colors.red,
                  ),
                  onTap: () {
                    final String userId = orderData['userId'] ?? 'Unknown User';
                    _showStatusDialog(order.id, status, userId);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
