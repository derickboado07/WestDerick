import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/screens/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 1. Get Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 2. Form key and controllers for changing password
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 3. State variable for loading
  bool _isLoading = false;

  // Profile snapshot values for display only
  String _displayName = '';
  String _phone = '';
  String _contactEmail = '';
  String _address = '';
  String _bankLast4 = '';
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
  _loadProfile();
  }

  // 4. Clean up controllers
  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_currentUser == null) return;
    try {
  final doc = await _firestore.collection('users').doc(_currentUser.uid).get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _displayName = (data['name'] ?? '').toString();
        _phone = (data['phone'] ?? '').toString();
        _contactEmail = (data['contactEmail'] ?? _currentUser.email ?? '').toString();
        _address = (data['address'] ?? '').toString();
        _bankLast4 = (data['bankAccountLast4'] ?? '').toString();
        _loadingProfile = false;
      });
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  // Change password logic
  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _currentUser!.updatePassword(_newPasswordController.text);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _formKey.currentState!.reset();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error changing password: ${e.code}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Logout logic
  Future<void> _signOut() async {
    try {
      // Get the Navigator before the async call to avoid context warnings
      final navigator = Navigator.of(context);
      await _auth.signOut();
      if (!mounted) return;
      // Pop all routes until the first (AuthWrapper will then show LoginScreen)
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error signing out'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User summary section
            Text('Profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_loadingProfile)
              const Center(child: CircularProgressIndicator())
            else ...[
              _infoRow('Email', _currentUser?.email ?? '—'),
              _infoRow('Name', _displayName.isEmpty ? 'Tap Edit to add' : _displayName),
              _infoRow('Contact', _phone.isEmpty ? 'Tap Edit to add' : _phone),
              _infoRow('Contact Email', _contactEmail.isEmpty ? (_currentUser?.email ?? '—') : _contactEmail),
              _infoRow('Address', _address.isEmpty ? 'Tap Edit to add' : _address),
              _infoRow('Bank Last4', _bankLast4.isEmpty ? '—' : '•••• $_bankLast4'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                onPressed: () async {
                  final changed = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  );
                  if (changed == true) {
                    _loadProfile();
                  }
                },
              ),
              const SizedBox(height: 32),
              const Divider(),
            ],
            const SizedBox(height: 16),

            // Change Password Form
            Text(
              'Change Password',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New Password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm Password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _changePassword,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Change Password'),
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: _signOut,
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
