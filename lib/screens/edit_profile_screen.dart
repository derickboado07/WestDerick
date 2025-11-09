import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snap = await _firestore.collection('users').doc(user.uid).get();
      final data = snap.data() ?? {};
      _nameController.text = (data['name'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      _contactEmailController.text = (data['contactEmail'] ?? user.email ?? '').toString();
      _addressController.text = (data['address'] ?? '').toString();
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    }
  }

  Future<void> _save() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final acct = _accountNumberController.text.trim();
      final last4 = acct.length >= 4 ? acct.substring(acct.length - 4) : '';

      final update = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'contactEmail': _contactEmailController.text.trim(),
        'address': _addressController.text.trim(),
        if (last4.isNotEmpty) 'bankAccountLast4': last4,
        if (last4.isNotEmpty) 'bankUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(update, SetOptions(merge: true));

      if (!mounted) return;
      _accountNumberController.clear();
      _cvvController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile saved.${last4.isNotEmpty ? ' Bank updated (•••• $last4).' : ''} CVV not stored.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _contactEmailController.dispose();
    _addressController.dispose();
    _accountNumberController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter your contact number';
                  final onlyDigits = v.replaceAll(RegExp(r'[^0-9+]'), '');
                  if (onlyDigits.length < 7) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactEmailController,
                decoration: const InputDecoration(labelText: 'Contact Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter your email';
                  final emailRx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRx.hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Payment Details', style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(labelText: 'Bank Account / Card Number (stored as last 4 only)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cvvController,
                decoration: const InputDecoration(labelText: 'CVV (never stored)'),
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'For security, we do not store your CVV or full account number. Only last 4 digits are saved.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
