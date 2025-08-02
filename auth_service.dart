import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService(this._firebaseAuth);

  // Listen to auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Sign in with email and password
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      print('User signed in: ${_firebaseAuth.currentUser?.uid}');
      return null;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.message}');
      return e.message;
    } catch (e) {
      print('Unexpected error during sign in: $e');
      return 'Sign in failed: $e';
    }
  }

  // Sign up and create user profile
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set display name for FirebaseAuth user
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();

      // Create initial user profile in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'name': name,
        'isProfileComplete': false,
      });

      print('User signed up: ${userCredential.user!.uid}');
      return 'Sign-up successful'; // Return success message
    } on FirebaseAuthException catch (e) {
      print('Sign up error: ${e.message}');
      return e.message;
    } catch (e) {
      print('Unexpected error during sign up: $e');
      return 'Sign up failed: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    print('User signed out');
  }

  // Save profile data in Firestore
  Future<String?> saveProfileData({
    required String uid,
    required String name,
    required String gender,
    required int age,
    required String emergencyContact1,
    required String emergencyContact2,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'gender': gender,
        'age': age,
        'emergencyContact1': emergencyContact1,
        'emergencyContact2': emergencyContact2,
        'isProfileComplete': true, // Mark profile as complete
      }, SetOptions(merge: true)); // Use merge to not overwrite other fields

      print('Profile saved for user: $uid');
      return 'Profile saved successfully';
    } catch (e) {
      print('Failed to save profile: $e');
      return 'Failed to save profile: $e';
    }
  }

  // Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        print('User profile fetched for $uid');
        return doc.data();
      } else {
        print('No user profile found for $uid');
        return null;
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
}
