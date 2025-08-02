import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db;  // Declare a variable to hold FirebaseFirestore instance

  // Constructor to initialize FirebaseFirestore
  FirestoreService(this._db);

  // Get User Profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final docSnapshot = await _db.collection('users').doc(uid).get();
      if (docSnapshot.exists) {
        return docSnapshot.data();  // Return user data if found
      } else {
        return null;  // Return null if no user data is found
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;  // In case of error, return null
    }
  }

  // Save User Profile data to Firestore
  Future<String?> saveUserProfile({
    required String uid,
    required String name,
    required String gender,
    required int age,
    required String emergencyContact1,
    required String emergencyContact2,
  }) async {
    try {
      await _db.collection('users').doc(uid).set({
        'name': name,
        'gender': gender,
        'age': age,
        'emergencyContact1': emergencyContact1,
        'emergencyContact2': emergencyContact2,
      });
      return null;  // Return null if everything goes well
    } catch (e) {
      print('Error saving user profile: $e');
      return 'Failed to save profile. Please try again later.';  // Return error message if save fails
    }
  }

  // Save a message to the Firestore chat collection
  Future<void> saveMessage({
    required String userId,
    required String message,
    required bool isUser,
  }) async {
    try {
      await _db.collection('chats').add({
        'userId': userId,
        'message': message,
        'isUser': isUser,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  // Fetch chat messages for a particular user
  Future<List<Map<String, dynamic>>> getChatMessages(String userId) async {
    try {
      final snapshot = await _db
          .collection('chats')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp')
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error fetching chat messages: $e');
      return [];
    }
  }
}
