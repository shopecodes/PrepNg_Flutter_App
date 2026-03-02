// lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's profile
  Future<UserModel?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        return UserModel.fromFirestore(doc.data()!, user.uid);
      }
      
      // If no profile exists, create a basic one
      return await _createBasicProfile(user);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Create basic profile for new users
  Future<UserModel> _createBasicProfile(User user) async {
    final userModel = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      isProfileComplete: false,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(user.uid).set(
      userModel.toFirestore(),
      SetOptions(merge: true),
    );

    return userModel;
  }

  // Check if user profile is complete
  Future<bool> isProfileComplete() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!doc.exists) return false;
      
      return doc.data()?['isProfileComplete'] ?? false;
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
      return false;
    }
  }

  // Complete user profile (NO IMAGE)
  Future<bool> completeProfile({
    required String displayName,
    required String department,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ Complete profile failed: No user logged in');
      return false;
    }

    try {
      debugPrint('📝 Completing profile for: ${user.email}');
      debugPrint('📝 Name: $displayName, Department: $department');

      // Update Firestore
      debugPrint('💾 Saving to Firestore...');
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': displayName,
        'department': department,
        'isProfileComplete': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Profile completed successfully!');
      return true;
    } catch (e) {
      debugPrint('❌ Error completing profile: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Update user profile (NO IMAGE)
  Future<bool> updateProfile({
    String? displayName,
    String? department,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ Update profile failed: No user logged in');
      return false;
    }

    try {
      debugPrint('📝 Updating profile for: ${user.email}');
      Map<String, dynamic> updates = {};

      if (displayName != null) {
        debugPrint('📝 Updating name: $displayName');
        updates['displayName'] = displayName;
      }
      if (department != null) {
        debugPrint('📝 Updating department: $department');
        updates['department'] = department;
      }

      if (updates.isNotEmpty) {
        debugPrint('💾 Saving ${updates.length} updates to Firestore...');
        await _firestore.collection('users').doc(user.uid).update(updates);
        debugPrint('✅ Profile updated successfully!');
      } else {
        debugPrint('⚠️ No updates to save');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Stream user profile changes
  Stream<UserModel?> userProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return UserModel.fromFirestore(doc.data()!, user.uid);
          }
          return null;
        });
  }
}