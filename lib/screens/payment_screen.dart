import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:ecommerce_app/screens/order_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_app/theme/app_theme.dart';

enum PaymentMethod { card, gcash, bank }

class PaymentScreen extends StatefulWidget {
  // 2. We need to know the total amount to be paid
  final double totalAmount;
  // Optional: used by collaborative payments
  final bool skipOrderPlacement;
  final Future<void> Function()? onPaid;

  // 3. The constructor will require this amount
  const PaymentScreen({
    super.key,
    required this.totalAmount,
    this.skipOrderPlacement = false,
    this.onPaid,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // 4. State variables to track selection and loading
  PaymentMethod _selectedMethod = PaymentMethod.card; // Default to card
  bool _isLoading = false;

  Future<void> _processPayment() async {
    // 1. Start loading spinner on the button
    setState(() {
      _isLoading = true;
    });

    try {
      // 2. --- THIS IS OUR MOCK API CALL ---
      //    We just wait for 3 seconds to simulate a network request
      //    to GCash, a bank, or a credit card processor.
      await Future.delayed(const Duration(seconds: 3));

      if (widget.skipOrderPlacement) {
        // Collaborative flow: mark paid and show success without placing order
        if (widget.onPaid != null) {
          await widget.onPaid!();
        }
      } else {
        // 3. If the "payment" is "successful" (i.e., the 3 seconds are up),
        //    we get the CartProvider.
        //    (listen: false is critical for calls inside functions)
        final cartProvider = Provider.of<CartProvider>(context, listen: false);

        // 4. Normal order placement
        await cartProvider.placeOrder();
        await cartProvider.clearCart();
      }

      // 5. If successful, navigate to success screen
      //    We use pushAndRemoveUntil to clear the cart/payment screens
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OrderSuccessScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // 6. Handle any errors from placing the order
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    } finally {
      // 7. ALWAYS stop loading, even if an error occurred
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedTotal = '₱${widget.totalAmount.toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Payment'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.borderGrey),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'Total Amount',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedTotal,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),

            // Payment method selection
            Text(
              'Select Payment Method',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Card option
            Card(
              child: RadioListTile<PaymentMethod>(
                title: Text(
                  'Credit/Debit Card',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: const Text('Visa, Mastercard, Amex'),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.paleGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.credit_card,
                    color: AppColors.primaryGold,
                  ),
                ),
                value: PaymentMethod.card,
                groupValue: _selectedMethod,
                activeColor: AppColors.primaryGold,
                onChanged: (PaymentMethod? value) {
                  setState(() {
                    _selectedMethod = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),

            // GCash option
            Card(
              child: RadioListTile<PaymentMethod>(
                title: Text(
                  'GCash',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: const Text('Pay via GCash app'),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.paleGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.phone_android,
                    color: AppColors.primaryGold,
                  ),
                ),
                value: PaymentMethod.gcash,
                groupValue: _selectedMethod,
                activeColor: AppColors.primaryGold,
                onChanged: (PaymentMethod? value) {
                  setState(() {
                    _selectedMethod = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),

            // Bank Transfer option
            Card(
              child: RadioListTile<PaymentMethod>(
                title: Text(
                  'Bank Transfer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: const Text('Direct bank transfer'),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.paleGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance,
                    color: AppColors.primaryGold,
                  ),
                ),
                value: PaymentMethod.bank,
                groupValue: _selectedMethod,
                activeColor: AppColors.primaryGold,
                onChanged: (PaymentMethod? value) {
                  setState(() {
                    _selectedMethod = value!;
                  });
                },
              ),
            ),

            const SizedBox(height: 40),

            // Pay button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: _isLoading ? null : _processPayment,
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlack,
                        ),
                      ),
                    )
                  : Text('PAY $formattedTotal'),
            ),
            
            const SizedBox(height: 16),
            
            // Security notice
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppColors.mediumGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your payment is secure and encrypted',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
