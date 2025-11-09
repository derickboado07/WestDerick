import 'package:flutter/material.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/widgets/suggested_product_item.dart';
import 'package:ecommerce_app/theme/app_theme.dart';

// 1. Convert to StatefulWidget so we can keep quantity state
class ProductDetailScreen extends StatefulWidget {
  // 2. We will pass in the product's data (the map)
  final Map<String, dynamic> productData;
  // 3. We'll also pass the unique product ID (critical for 'Add to Cart' later)
  final String productId;

  // 4. The constructor takes both parameters
  const ProductDetailScreen({
    super.key,
    required this.productData,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // 4. ADD OUR NEW STATE VARIABLE FOR QUANTITY
  int _quantity = 1;

  // 1. ADD THIS FUNCTION
  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  // 2. ADD THIS FUNCTION
  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.productData['name'];
    final String description = widget.productData['description'];
    final String imageUrl = widget.productData['imageUrl'];
    // Price coming from Firestore can be an int, double, or even a string.
    // Parse it robustly so we don't crash when an int is provided.
    final rawPrice = widget.productData['price'];
    double price = 0.0;
    if (rawPrice is num) {
      price = rawPrice.toDouble();
    } else if (rawPrice is String) {
      price = double.tryParse(rawPrice) ?? 0.0;
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          // Elegant App Bar with image
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: AppColors.pureWhite,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGold,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.lightGrey,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 100,
                        color: AppColors.mediumGrey,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Product details
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.pureWhite,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      name,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 12),

                    // Price with gold accent
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.paleGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₱${price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.richGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    
                    // Description section
                    Text(
                      'About This Product',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Quantity selector
                    Text(
                      'Quantity',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderGrey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: _decrementQuantity,
                            color: AppColors.primaryBlack,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              '$_quantity',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _incrementQuantity,
                            color: AppColors.primaryBlack,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),

                    // Add to cart button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final cart = Provider.of<CartProvider>(context, listen: false);
                          cart.addItem(
                            widget.productId,
                            name,
                            price,
                            _quantity,
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added $_quantity x $name to cart'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('ADD TO CART'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          
          // Suggested products section
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.lightGrey,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You Might Also Like',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('products')
                          .orderBy('createdAt', descending: true)
                          .limit(20)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGold,
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load suggestions',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final docs = snapshot.data!.docs
                            .where((d) => d.id != widget.productId)
                            .toList();
                        if (docs.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final maxItems = docs.length >= 12 ? 12 : (docs.length >= 6 ? docs.length : docs.length);
                        final suggestions = docs.take(maxItems).toList();

                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          itemCount: suggestions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final doc = suggestions[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final sName = (data['name'] ?? 'Unnamed').toString();
                            final sImage = (data['imageUrl'] ?? '').toString();
                            double sPrice = 0.0;
                            final rawPrice = data['price'];
                            if (rawPrice is num) {
                              sPrice = rawPrice.toDouble();
                            } else if (rawPrice is String) {
                              sPrice = double.tryParse(rawPrice) ?? 0.0;
                            }

                            return SuggestedProductItem(
                              name: sName,
                              price: sPrice,
                              imageUrl: sImage,
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      productData: data,
                                      productId: doc.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
