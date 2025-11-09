import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ecommerce_app/widgets/order_card_widget.dart'; // Import clean card widget

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: user == null
          ? const Center(
              child: Text('Please log in to see your orders.'),
            )
      : StreamBuilder<QuerySnapshot>(
        // NOTE: Removed server-side orderBy to avoid Firestore composite-index requirement.
        // We fetch only the current user's orders and sort them client-side by `createdAt`.
        stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
        builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('You have not placed any orders yet.'),
                  );
                }

                // Copy docs to a mutable list and sort by createdAt (newest first)
                final docs = snapshot.data!.docs.toList();

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aTs = aData['createdAt'];
                  final bTs = bData['createdAt'];

                  if (aTs is Timestamp && bTs is Timestamp) {
                    return bTs.compareTo(aTs);
                  }
                  // If either timestamp is missing or not a Timestamp, keep original order
                  return 0;
                });

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final orderData = docs[index].data() as Map<String, dynamic>;
                    return OrderCardWidget(orderData: orderData);
                  },
                );
              },
            ),
    );
  }
}
