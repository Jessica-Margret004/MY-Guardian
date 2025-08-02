import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _contactController1 = TextEditingController();
  final TextEditingController _contactController2 = TextEditingController();

  String _gender = 'Female';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load user data from Firestore
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        final userData = await firestoreService.getUserProfile(user.uid);

        if (userData != null && mounted) {
          setState(() {
            _nameController.text = userData['name'] ?? '';
            _gender = userData['gender'] ?? 'Female';
            _ageController.text = userData['age']?.toString() ?? '';
            _contactController1.text = userData['emergencyContact1'] ?? '';
            _contactController2.text = userData['emergencyContact2'] ?? '';
          });
        }
      } catch (e) {
        print('Error loading profile data: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _contactController1.dispose();
    _contactController2.dispose();
    super.dispose();
  }

  // Save user profile data to Firestore
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final firestoreService = Provider.of<FirestoreService>(context, listen: false);
          final error = await firestoreService.saveUserProfile(
            uid: user.uid,
            name: _nameController.text.trim(),
            gender: _gender,
            age: int.parse(_ageController.text.trim()),
            emergencyContact1: _contactController1.text.trim(),
            emergencyContact2: _contactController2.text.trim(),
          );

          setState(() => _isLoading = false);

          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          } else {
            Navigator.of(context).pushReplacementNamed('/safety'); // Navigate to safety screen
          }
        } catch (e) {
          setState(() => _isLoading = false);
          print('Exception during saving: $e');
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('An error occurred. Please try again.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Setup'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut(); // Logout user
              Navigator.of(context).pushReplacementNamed('/signin');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Profile',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This information will be used in emergency situations.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 20),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Select Gender',
                    prefixIcon: Icon(Icons.wc),
                    border: OutlineInputBorder(),
                  ),
                  items: ['Female', 'Male', 'Other'].map((gender) {
                    return DropdownMenuItem(value: gender, child: Text(gender));
                  }).toList(),
                  onChanged: (value) => setState(() => _gender = value!),
                ),
                const SizedBox(height: 20),

                // Age Field
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final age = int.tryParse(value ?? '');
                    if (value == null || value.isEmpty) return 'Please enter your age';
                    if (age == null || age <= 0) return 'Please enter a valid age';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Emergency Contact 1
                TextFormField(
                  controller: _contactController1,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact 1',
                    prefixIcon: Icon(Icons.phone),
                    hintText: '10-digit phone number',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) =>
                      value == null || value.length != 10 ? 'Enter valid 10-digit number' : null,
                ),
                const SizedBox(height: 20),

                // Emergency Contact 2
                TextFormField(
                  controller: _contactController2,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact 2',
                    prefixIcon: Icon(Icons.phone),
                    hintText: '10-digit phone number',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) =>
                      value == null || value.length != 10 ? 'Enter valid 10-digit number' : null,
                ),
                const SizedBox(height: 40),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SAVE PROFILE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
