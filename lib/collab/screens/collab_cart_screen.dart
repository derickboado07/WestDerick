import 'package:ecommerce_app/collab/providers/collab_cart_provider.dart';
import 'package:ecommerce_app/collab/services/firestore_collab_service.dart';
import 'package:ecommerce_app/collab/screens/collab_payment_screen.dart';
// Removed direct PaymentScreen import (not used after finalize refactor)
import 'package:ecommerce_app/screens/order_success_screen.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class CollabCartScreen extends StatelessWidget {
  const CollabCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CollabCartProvider(service: FirestoreCollabService()),
      child: const _CollabCartBody(),
    );
  }
}

class _CollabCartBody extends StatefulWidget {
  const _CollabCartBody();

  @override
  State<_CollabCartBody> createState() => _CollabCartBodyState();
}

class _CollabCartBodyState extends State<_CollabCartBody> {
  final _nameCtrl = TextEditingController();
  final _joinCtrl = TextEditingController();
  final Map<String, bool> _paidSeen = {}; // for in-app notifications when others pay

  @override
  Widget build(BuildContext context) {
    final collab = context.watch<CollabCartProvider>();
    final cart = context.watch<CartProvider>();
    final session = collab.session;

    // In-app notifications: show when another participant completes payment
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final myId = collab.myParticipantId;
        final allPaid = session.participants.every((p) => p.hasPaid);
        for (final p in session.participants) {
          final prev = _paidSeen[p.id] ?? false;
          if (!prev && p.hasPaid && p.id != myId) {
            _paidSeen[p.id] = true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${p.displayName} has completed their payment.')),
              );
            }
          } else {
            _paidSeen[p.id] = p.hasPaid;
          }
        }
        if (allPaid && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All shares paid. Host can finalize the order.')),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(session == null
            ? 'Collaborative Cart'
            : 'Collaborative Cart (${session.participants.length})'),
        actions: [
          if (session != null)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Leave Session',
              onPressed: () => collab.leaveSession(),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (session == null) ...[
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: collab.isBusy
                          ? null
                          : () => collab.createSession(displayName: _nameCtrl.text.trim().isEmpty ? 'Host' : _nameCtrl.text.trim()),
                      child: const Text('Create Session'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              TextField(
                controller: _joinCtrl,
                decoration: const InputDecoration(labelText: 'Enter Session ID'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: collab.isBusy
                    ? null
                    : () => collab.joinSession(
                          sessionId: _joinCtrl.text.trim(),
                          displayName: _nameCtrl.text.trim().isEmpty ? 'Guest' : _nameCtrl.text.trim(),
                        ),
                child: const Text('Join Session'),
              ),
              if (collab.error != null) ...[
                const SizedBox(height: 12),
                Text(collab.error!, style: const TextStyle(color: Colors.red)),
              ],
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Session: ${session.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => Share.share('Join my cart: ${session.id}'),
                    icon: const Icon(Icons.ios_share),
                    tooltip: 'Share ID',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: QrImageView(
                  data: session.id,
                  size: 160,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Participants', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Participants: ${session.participants.length}'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: session.participants
                        .map((p) => Chip(
                              label: Text(p.displayName + (p.isHost ? ' (Host)' : '')),
                            ))
                        .toList(),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cart Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => collab.importItems(cart.items),
                    child: const Text('Import from My Cart'),
                  ),
                ],
              ),
              if ((session.cartSnapshot['items'] as List?)?.isEmpty ?? true)
                const Text('No items imported yet.')
              else
                ...((session.cartSnapshot['items'] as List)
                    .map((e) => ListTile(
                          title: Text('${e['name']} x${e['quantity']}'),
                          trailing: Text('₱${((e['price'] as num) * (e['quantity'] as num)).toStringAsFixed(2)}'),
                        ))
                    .toList()),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Subtotal: ₱${((session.cartSnapshot['subtotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 24),
              const Text('Split Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: collab.setEqualSplit,
                    child: const Text('Equal Split'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (session.splitPlan != null) ...[
                ...session.splitPlan!.shares.map((s) {
                  final p = session.participants.firstWhere((e) => e.id == s.participantId, orElse: () => session.participants.first);
                  return ListTile(
                    title: Text(p.displayName),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₱${s.amount.toStringAsFixed(2)}'),
                        const SizedBox(width: 8),
                        Icon(p.hasPaid ? Icons.check_circle : Icons.pending, color: p.hasPaid ? Colors.green : Colors.orange, size: 18),
                      ],
                    ),
                    subtitle: s.percentage != null ? Text('${s.percentage!.toStringAsFixed(1)}%') : null,
                  );
                }).toList(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    final provider = context.read<CollabCartProvider>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: const CollabPaymentScreen(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Proceed to Payment'),
                ),
                const SizedBox(height: 12),
                // Host finalize order when all have paid
                Builder(builder: (context) {
                  final provider = context.watch<CollabCartProvider>();
                  final allPaid = session.participants.every((p) => p.hasPaid);
                  final hostId = session.hostParticipantId;
                  final isHost = provider.myParticipantId == hostId;
                  if (!allPaid || !isHost) return const SizedBox.shrink();
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () async {
                      try {
                        // Create an order visible to admin and mark session closed
                        final uid = FirebaseAuth.instance.currentUser?.uid ?? provider.myParticipantId ?? 'unknown';
                        final orderId = await provider.service.finalizeCollaborativeOrder(
                          session: session,
                          createdByUserId: uid,
                        );
                        if (!mounted) return;
                        // Clear my cart locally (other participants cleared when they paid)
                        await context.read<CartProvider>().clearCart();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Collaborative order placed (ID: $orderId).')),
                        );
                        // Navigate to success screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OrderSuccessScreen(),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to finalize order: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Finalize Order'),
                  );
                }),
              ] else
                const Text('Choose a split method to calculate shares.'),
            ]
          ],
        ),
      ),
    );
  }
}
