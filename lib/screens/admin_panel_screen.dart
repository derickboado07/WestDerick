import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/screens/admin_order_screen.dart';
import 'package:ecommerce_app/screens/admin_chat_list_screen.dart';
import 'package:ecommerce_app/screens/manage_products_screen.dart';
import 'package:ecommerce_app/theme/app_theme.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  // 1. A key to validate our Form
  final _formKey = GlobalKey<FormState>();

  // 2. Controllers for each text field
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController(); // For the image link

  // 3. A variable to show a loading spinner
  bool _isLoading = false;

  // 4. An instance of Firestore to save data
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 5. Clean up the controllers
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _uploadProduct() async {
    // 1. First, check if all form fields are valid
    if (!_formKey.currentState!.validate()) {
      return; // If not, do nothing
    }

    // 2. Show the loading spinner
    setState(() {
      _isLoading = true;
    });

    try {
      // 3. Get the text from our URL controller
      String imageUrl = _imageUrlController.text.trim();

      // 4. Add the data to a new 'products' collection
      await _firestore.collection('products').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        // 5. Try to parse the price text as a number
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'imageUrl': imageUrl, // 6. Save the URL string
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 7. If successful, show a confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product uploaded successfully!')),
        );
      }

      // 8. Clear all the text fields
      _formKey.currentState!.reset();
      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _imageUrlController.clear();

    } catch (e) {
      // 9. If something went wrong, show an error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload product: $e')),
        );
      }
    } finally {
      // 10. ALWAYS hide the loading spinner
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            tooltip: 'Manage Products',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageProductsScreen(),
                ),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Manage Products button - no icon as requested
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManageProductsScreen(),
                    ),
                  );
                },
                child: const Text('Manage Products'),
              ),
              const SizedBox(height: 12),
              
              // Manage All Orders button
              ElevatedButton.icon(
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('Manage All Orders'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AdminOrderScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              
              // View User Chats button
              ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('View User Chats'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AdminChatListScreen(),
                    ),
                  );
                },
              ),

              // Separator before Add New Product form
              const SizedBox(height: 24),
              const Divider(height: 30, thickness: 1),
              const SizedBox(height: 8),

              Text(
                'Add New Product',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // 6. The rest of your form (wrapped in its own Form widget)
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 4. The "Image URL" text field
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(labelText: 'Image URL'),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an image URL';
                        }
                        if (!value.startsWith('http')) {
                          return 'Please enter a valid URL (e.g., http://...)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 5. The "Product Name" text field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Product Name'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),

                    // 6. The "Description" text field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3, // Makes the field taller
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter a description' : null,
                    ),
                    const SizedBox(height: 16),

                    // 7. The "Price" text field
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number, // Shows number keyboard
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 8. The "Upload" Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      // 9. If loading, disable the button
                      onPressed: _isLoading ? null : _uploadProduct,
                      // 10. If loading, show spinner, else show text
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Upload Product'),
                    ),
                  ],
                ),
              ),

              // Inline Manage Products list removed to avoid redundancy.
            ],
          ),
        ),
      ),
    );
  }
}

