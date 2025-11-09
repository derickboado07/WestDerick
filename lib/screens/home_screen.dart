import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/screens/admin_panel_screen.dart';
import 'package:ecommerce_app/widgets/product_card.dart';
import 'package:ecommerce_app/screens/product_detail_screen.dart';
import 'package:ecommerce_app/screens/order_history_screen.dart';
import 'package:ecommerce_app/screens/profile_screen.dart';
import 'package:ecommerce_app/widgets/notification_icon.dart';
import 'package:ecommerce_app/screens/chat_screen.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:ecommerce_app/screens/cart_screen.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_app/theme/app_theme.dart';
import 'package:ecommerce_app/screens/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Default role
  String _userRole = 'user';
  // Current user
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  // Bottom navigation selected index
  int _selectedIndex = -1; // -1 means none explicitly selected yet

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    if (_currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _userRole = doc.data()!['role'] ?? 'user';
        });
      }
    } catch (e) {
      // Keep default 'user' role on error
      debugPrint('Error fetching user role: $e');
    }
  }

  // _signOut removed from here; logout will be handled from ProfileScreen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        centerTitle: false,
        leadingWidth: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: SizedBox(
            height: 40,
            child: Image.asset(
              'assets/images/splash_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: Text(
          'Scenteur Essentials', // renamed from Scenture to Scenteur
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('createdAt', descending: true)
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading products',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.mediumGrey),
                  const SizedBox(height: 16),
                  Text(
                    'No products available',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back soon for new items!',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          final products = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final productDoc = products[index];
              final productData = productDoc.data() as Map<String, dynamic>;

              double price = 0.0;
              try {
                final rawPrice = productData['price'];
                if (rawPrice is num) {
                  price = rawPrice.toDouble();
                } else if (rawPrice is String) {
                  price = double.tryParse(rawPrice) ?? 0.0;
                }
              } catch (_) {
                price = 0.0;
              }

              final name = (productData['name'] ?? 'Unnamed Product').toString();
              final imageUrl = (productData['imageUrl'] ?? '').toString();

              return ProductCard(
                productName: name,
                price: price,
                imageUrl: imageUrl,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(
                        productData: productData,
                        productId: productDoc.id,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: _userRole == 'user' && _currentUser != null
          ? StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data();
                  if (data != null) {
                    unreadCount = (data as Map<String, dynamic>)['unreadByUserCount'] ?? 0;
                  }
                }
                return Badge(
                  label: Text('$unreadCount'),
                  isLabelVisible: unreadCount > 0,
                  backgroundColor: AppColors.error,
                  textColor: AppColors.pureWhite,
                  child: FloatingActionButton.extended(
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Admin'),
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.primaryBlack,
                    elevation: 4,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatRoomId: _currentUser.uid,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            )
          : null,
      // Bottom navigation bar consolidating previous AppBar actions
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    // Build list of items; admin item conditional
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: Consumer<CartProvider>(
          builder: (context, cart, child) {
            return Badge(
              label: Text(cart.itemCount.toString()),
              isLabelVisible: cart.itemCount > 0,
              backgroundColor: AppColors.primaryGold,
              textColor: AppColors.primaryBlack,
              child: const Icon(Icons.shopping_bag_outlined),
            );
          },
        ),
        label: 'Cart',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.groups_2_outlined),
        label: 'Collab',
      ),
      // Notifications - shows unread badge
      const BottomNavigationBarItem(
        icon: NotificationIcon(),
        label: 'Notify',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long_outlined),
        label: 'Orders',
      ),
      if (_userRole == 'admin')
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          label: 'Admin',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
      ),
    ];

    return BottomNavigationBar(
      currentIndex: _selectedIndex >= 0 && _selectedIndex < items.length ? _selectedIndex : 0,
      type: BottomNavigationBarType.fixed,
      items: items,
      onTap: (index) => _onNavTap(index, items.length),
    );
  }

  void _onNavTap(int index, int itemCount) {
    setState(() => _selectedIndex = index);
  // Map taps to the same navigation actions formerly in AppBar
    // Index mapping (when admin present): 0 Cart,1 Collab,2 Notify,3 Orders,4 Admin,5 Profile
    // Without admin: 0 Cart,1 Collab,2 Notify,3 Orders,4 Profile
    switch (index) {
      case 0:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
        break;
      case 1:
        Navigator.of(context).pushNamed('/collab-cart');
        break;
      case 2:
        // Open notifications screen
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
      case 3:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
        );
        break;
      default:
        // Admin present scenario
        if (_userRole == 'admin') {
          if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
            );
            return;
          }
          if (index == 5) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            return;
          }
        }
        // Non-admin profile index (4)
        if (_userRole != 'admin' && index == 4) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        }
        break;
    }
  }
}
