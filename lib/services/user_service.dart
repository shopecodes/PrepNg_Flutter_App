// lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reads a Firestore doc cache-first.
  /// 1. Tries local cache instantly — works offline, zero latency.
  /// 2. If cache misses (first ever launch), falls back to server with
  ///    a 30-second timeout so a slow network never hangs the app forever.
  Future<DocumentSnapshot<Map<String, dynamic>>> _getDoc(
      String collection, String docId) async {
    try {
      final cached = await _firestore
          .collection(collection)
          .doc(docId)
          .get(const GetOptions(source: Source.cache));
      if (cached.exists) {
        debugPrint('📦 Cache hit: $collection/$docId');
        return cached;
      }
    } catch (_) {
      // Cache miss — fall through to server
    }

    debugPrint('🌐 Cache miss — fetching from server: $collection/$docId');
    return await _firestore
        .collection(collection)
        .doc(docId)
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception(
              'Could not load your profile. Please check your internet.'),
        );
  }

  // Get current user's profile
  Future<UserModel?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _getDoc('users', user.uid);

      if (doc.exists) {
        return UserModel.fromFirestore(doc.data()!, user.uid);
      }

      // No profile exists — create a basic one
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

  // Check if user profile is complete — cache-first so it works offline
  Future<bool> isProfileComplete() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _getDoc('users', user.uid);
      if (!doc.exists) return false;
      return doc.data()?['isProfileComplete'] ?? false;
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
      // If we can't reach server and there's no cache, default to
      // false so user can complete their profile rather than being stuck
      return false;
    }
  }

  // Complete user profile
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

  // Update user profile
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