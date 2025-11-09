import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_app/collab/providers/collab_cart_provider.dart';
import 'package:ecommerce_app/collab/models/split_payment.dart';
import 'package:ecommerce_app/screens/payment_screen.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';

class CollabPaymentScreen extends StatefulWidget {
  const CollabPaymentScreen({super.key});

  @override
  State<CollabPaymentScreen> createState() => _CollabPaymentScreenState();
}

class _CollabPaymentScreenState extends State<CollabPaymentScreen> {
  bool _processing = false;
  String? _error;
  final Map<String, bool> _paidSeen = {}; // track notifications shown for paid participants

  void _payShare() {
    final collab = context.read<CollabCartProvider>();
    final session = collab.session;
    if (session == null || session.splitPlan == null) return;
  final unpaid = session.participants.where((p) => !p.hasPaid).toList();
    final target = unpaid.isEmpty ? session.participants.first : unpaid.first;
    final share = session.splitPlan!.shares.firstWhere(
      (s) => s.participantId == target.id,
      orElse: () => SplitPaymentShare(participantId: target.id, amount: 0),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          totalAmount: share.amount,
          skipOrderPlacement: true,
          onPaid: () async {
            // 1) Mark me paid in the session
            await collab.service.markParticipantPaid(session.id, target.id, share.amount);
            // 2) Clear my local cart so "Your Cart" reflects payment immediately
            if (mounted) {
              try {
                final cart = Provider.of<CartProvider>(context, listen: false);
                await cart.clearCart();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment complete. Your cart has been cleared.')),
                );
              } catch (_) {}
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collab = context.watch<CollabCartProvider>();
    final session = collab.session;
    final split = session?.splitPlan;
    if (session == null || split == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pay My Share')),
        body: const Center(child: Text('No active split plan. Return and choose Equal Split.')),
      );
    }

  final allPaid = session.participants.every((p) => p.hasPaid);

    // Simple in-app notifications when others pay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final myId = collab.myParticipantId;
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
      if (allPaid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All shares paid. Host may finalize the order.')),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Pay My Share')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session ID: ${session.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (allPaid)
              const Card(
                color: Colors.green,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('All participants have completed payment.', style: TextStyle(color: Colors.white)),
                ),
              )
            else
              const Text('Pending payments:'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: session.participants.map((p) {
                  final share = split.shares.firstWhere((s) => s.participantId == p.id, orElse: () => SplitPaymentShare(participantId: p.id, amount: 0));
                  return ListTile(
                    leading: Icon(p.hasPaid ? Icons.check_circle : Icons.pending, color: p.hasPaid ? Colors.green : Colors.orange),
                    title: Text(p.displayName + (p.isHost ? ' (Host)' : '')),
                    subtitle: Text('Share: ₱${share.amount.toStringAsFixed(2)}'),
                    trailing: p.hasPaid
                        ? const Text('Paid', style: TextStyle(color: Colors.green))
                        : const Text('Unpaid', style: TextStyle(color: Colors.orange)),
                  );
                }).toList(),
              ),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            if (!allPaid)
              ElevatedButton.icon(
                onPressed: _processing ? null : _payShare,
                icon: const Icon(Icons.payment),
                label: const Text('Pay My Share'),
              ),
            if (allPaid)
              const Text('All shares paid. Host may finalize order.', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
