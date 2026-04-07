// lib/services/progress_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'offline_service.dart';

class ProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Save quiz result — queues offline if write fails ──────────
  Future<void> saveQuizResult({
    required String subjectName,
    required int score,
    required int totalQuestions,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'userId': user.uid,
      'subjectName': subjectName,
      'score': score,
      'totalQuestions': totalQuestions,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _db.collection('results').add(data);
      await OfflineService.markOnline();
    } catch (e) {
      debugPrint('Progress write failed — queuing: $e');
      final queueData = Map<String, dynamic>.from(data);
      queueData['timestamp'] = '__serverTimestamp__';
      await OfflineService.queueWrite(
        collection: 'results',
        data: queueData,
      );
    }
  }

  // ── Stream results — cache-first via Firestore persistence ────
  // Firestore's offline persistence handles this automatically when
  // persistenceEnabled:true is set in main.dart. The stream returns
  // cached data immediately and updates when online.
  Stream<QuerySnapshot> getUserResults() {
    return _db
        .collection('results')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ── Clear history ─────────────────────────────────────────────
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