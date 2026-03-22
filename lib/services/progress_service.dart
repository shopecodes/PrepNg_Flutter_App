// lib/services/progress_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save quiz result — field is 'timestamp' everywhere
  Future<void> saveQuizResult({
    required String subjectName,
    required int score,
    required int totalQuestions,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db.collection('results').add({
        'userId': user.uid,
        'subjectName': subjectName,
        'score': score,
        'totalQuestions': totalQuestions,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get all user results ordered by 'timestamp'
  Stream<QuerySnapshot> getUserResults() {
    return _db
        .collection('results')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Clear history from BOTH collections
  Future<bool> clearUserHistory() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    int deletedCount = 0;

    try {
      final resultsSnapshot = await _db
          .collection('results')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (DocumentSnapshot doc in resultsSnapshot.docs) {
        await doc.reference.delete();
        deletedCount++;
      }

      final mockResultsSnapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('mock_results')
          .get();

      for (DocumentSnapshot doc in mockResultsSnapshot.docs) {
        await doc.reference.delete();
        deletedCount++;
      }

      return deletedCount > 0;
    } catch (e) {
      debugPrint('Error clearing history: $e');
      return false;
    }
  }
}