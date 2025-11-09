import 'dart:async'; // for StreamSubscription
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. A simple class to hold the data for an item in the cart
class CartItem {
  final String id; // The unique product ID
  final String name;
  final double price;
  int quantity; // Quantity can change, so it's not final

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  // 1. A method to convert our CartItem object into a Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  // 2. A factory constructor to create a CartItem from a Map
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
    );
  }
}

// 1. The CartProvider class "mixes in" ChangeNotifier
class CartProvider with ChangeNotifier {
  // 2. This is the private list of items. Not final because we may replace it
  List<CartItem> _items = [];

  // 5. New properties for auth and database
  String? _userId; // Will hold the current user's ID
  StreamSubscription<User?>? _authSubscription; // To listen to auth changes

  // 6. Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 3. A public "getter" to let widgets *read* the list of items
  List<CartItem> get items => _items;

  // 4. A public "getter" to calculate the total number of items
  int get itemCount {
    // This 'fold' is a cleaner way to sum a list.
    return _items.fold(0, (total, item) => total + item.quantity);
  }

  // --- THIS IS THE GETTERS SECTION ---
  // 1. RENAME 'totalPrice' to 'subtotal'
  //    This is the total price *before* tax.
  double get subtotal {
    double total = 0.0;
    for (var item in _items) {
      total += (item.price * item.quantity);
    }
    return total;
  }

  // 2. ADD this new getter for VAT (12%)
  double get vat {
    return subtotal * 0.12; // 12% of the subtotal
  }

  // 3. ADD this new getter for the FINAL total
  double get totalPriceWithVat {
    return subtotal + vat;
  }

  // 7. Constructor: listen to auth changes and fetch/clear cart accordingly
  CartProvider() {
    print('CartProvider initialized');
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        // User logged out
        print('User logged out, clearing cart.');
        _userId = null;
        _items = [];
      } else {
        // User logged in
        print('User logged in: ${user.uid}. Fetching cart...');
        _userId = user.uid;
        _fetchCart();
      }
      notifyListeners();
    });
  }

  // 6. The main logic: "Add Item to Cart"
  // Updated to accept a quantity parameter so callers can add multiple units at once
  void addItem(String id, String name, double price, int quantity) {
    // 7. Check if the item is already in the cart
    var index = _items.indexWhere((item) => item.id == id);

    if (index != -1) {
      // 8. If YES: add the new quantity to the existing quantity
      _items[index].quantity += quantity;
    } else {
      // 9. If NO: add it to the list as a new item with the specified quantity
      _items.add(CartItem(id: id, name: name, price: price, quantity: quantity));
    }

    // Save to Firestore (if logged in) and then notify UI
    _saveCart(); // best-effort, async
    notifyListeners();
  }

  // 11. The "Remove Item from Cart" logic
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _saveCart(); // best-effort, async
    notifyListeners(); // Tell widgets to rebuild
  }

  // 8. Fetches the cart from Firestore
  Future<void> _fetchCart() async {
    if (_userId == null) return;

    try {
      final doc = await _firestore.collection('userCarts').doc(_userId).get();

      if (doc.exists && doc.data() != null && doc.data()!['cartItems'] != null) {
        final List<dynamic> cartData = doc.data()!['cartItems'];
        _items = cartData.map((item) => CartItem.fromJson(Map<String, dynamic>.from(item))).toList();
        print('Cart fetched successfully: ${_items.length} items');
      } else {
        _items = [];
      }
    } catch (e) {
      print('Error fetching cart: $e');
      _items = [];
    }
    notifyListeners();
  }

  // 9. Saves the current local cart to Firestore
  Future<void> _saveCart() async {
    if (_userId == null) return;

    try {
      final List<Map<String, dynamic>> cartData = _items.map((item) => item.toJson()).toList();
      await _firestore.collection('userCarts').doc(_userId).set({
        'cartItems': cartData,
      });
      print('Cart saved to Firestore');
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  // 1. ADD THIS: Creates an order in the 'orders' collection
  Future<void> placeOrder() async {
    // 2. Check if we have a user and items
    if (_userId == null || _items.isEmpty) {
      // Don't place an order if cart is empty or user is logged out
      throw Exception('Cart is empty or user is not logged in.');
    }

    try {
      // 3. Convert our List<CartItem> to a List<Map> using toJson()
      final List<Map<String, dynamic>> cartData = 
          _items.map((item) => item.toJson()).toList();
      
      // 4. --- THIS IS THE CHANGE ---
      //    Get all our new calculated values
      final double sub = subtotal;
      final double v = vat;
      final double total = totalPriceWithVat;
      final int count = itemCount;

      // 5. Update the data we save to Firestore
      await _firestore.collection('orders').add({
        'userId': _userId,
        'items': cartData,
        'subtotal': sub,       // 3. ADD THIS
        'vat': v,            // 4. ADD THIS
        'totalPrice': total,   // 5. This is now the VAT-inclusive price
        'itemCount': count,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // 7. Note: We DO NOT clear the cart here.
      //    We'll call clearCart() separately from the UI after this succeeds.
      
    } catch (e) {
      print('Error placing order: $e');
      // 8. Re-throw the error so the UI can catch it
      rethrow; 
    }
  }

  // 9. ADD THIS: Clears the cart locally AND in Firestore
  Future<void> clearCart() async {
    // 10. Clear the local list
    _items = [];
    
    // 11. If logged in, clear the Firestore cart as well
    if (_userId != null) {
      try {
        // 12. Set the 'cartItems' field in their cart doc to an empty list
        await _firestore.collection('userCarts').doc(_userId).set({
          'cartItems': [],
        });
        print('Firestore cart cleared.');
      } catch (e) {
        print('Error clearing Firestore cart: $e');
      }
    }
    
    // 13. Notify all listeners (this will clear the UI)
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
