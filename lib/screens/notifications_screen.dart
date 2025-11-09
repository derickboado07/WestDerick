import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting the date
import 'package:ecommerce_app/screens/order_detail_screen.dart';
import 'dart:async';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Manual bulk actions
  Future<void> _markAll(bool read) async {
    if (_user == null) return;
    try {
    final query = await _firestore
      .collection('notifications')
      .where('userId', isEqualTo: _user.uid)
          .get();
      if (query.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final d in query.docs) {
        batch.update(d.reference, {'isRead': read});
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(read ? 'All marked read' : 'All marked unread')),
      );
    } catch (e) {
      debugPrint('Bulk mark failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _toggleRead(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final bool isRead = data['isRead'] == true;
      await doc.reference.update({'isRead': !isRead});
    } catch (e) {
      debugPrint('Toggle read failed: $e');
    }
  }

  // (no-op) helper removed; we now sort client-side to avoid composite index requirement

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: _user == null
            ? []
            : [
                IconButton(
                  tooltip: 'Mark all read',
                  icon: const Icon(Icons.done_all),
                  onPressed: () => _markAll(true),
                ),
                IconButton(
                  tooltip: 'Mark all unread',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _markAll(false),
                ),
              ],
      ),
      body: _user == null
          ? const Center(child: Text('Please log in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .where('userId', isEqualTo: _user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Failed to load notifications.\n${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('You have no notifications.'));
                }

                final docs = [...snapshot.data!.docs];
                docs.sort((a, b) {
                  final ma = a.data() as Map<String, dynamic>;
                  final mb = b.data() as Map<String, dynamic>;
                  final ta = (ma['createdAt'] as Timestamp?) ?? (ma['createdAtServer'] as Timestamp?);
                  final tb = (mb['createdAt'] as Timestamp?) ?? (mb['createdAtServer'] as Timestamp?);
                  final va = ta?.millisecondsSinceEpoch ?? 0;
                  final vb = tb?.millisecondsSinceEpoch ?? 0;
                  return vb.compareTo(va);
                });

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final ts = (data['createdAt'] as Timestamp?) ?? (data['createdAtServer'] as Timestamp?);
                    final formattedDate = ts != null
                        ? DateFormat('MM/dd/yy hh:mm a').format(ts.toDate())
                        : '';
                    final bool isUnread = data['isRead'] == false;

                    return ListTile(
                      onTap: () async {
                        // Open target if available
                        final orderId = (data['orderId'] ?? '').toString();
                        if (orderId.isNotEmpty) {
                          // Optionally mark as read when user opens it
                          if (isUnread) {
                            try { await doc.reference.update({'isRead': true}); } catch (_) {}
                          }
                          if (!context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OrderDetailScreen(orderId: orderId),
                            ),
                          );
                        } else {
                          // No target, fallback to toggling read state
                          await _toggleRead(doc);
                        }
                      },
                      leading: isUnread
                          ? const Icon(Icons.circle, color: Colors.deepPurple, size: 12)
                          : const Icon(Icons.circle_outlined, color: Colors.grey, size: 12),
                      title: Text(
                        (data['title'] ?? 'No Title').toString(),
                        style: TextStyle(
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text('${(data['body'] ?? '').toString()}\n$formattedDate'),
                      trailing: IconButton(
                        icon: Icon(
                          isUnread ? Icons.mark_email_read : Icons.mark_email_unread,
                          size: 20,
                        ),
                        tooltip: isUnread ? 'Mark read' : 'Mark unread',
                        onPressed: () => _toggleRead(doc),
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
            ),
    );
  }
}
