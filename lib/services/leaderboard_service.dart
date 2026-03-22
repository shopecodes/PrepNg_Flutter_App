// lib/services/leaderboard_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String department;
  final int totalScore;
  final int quizzesTaken;
  final double averageScore;
  final int rank;

  LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.department,
    required this.totalScore,
    required this.quizzesTaken,
    required this.averageScore,
    required this.rank,
  });
}

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Get current week ID (e.g. "2025-W12") ─────────────────────
  String get _currentWeekId {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final weekNumber = ((now.difference(startOfYear).inDays + startOfYear.weekday) / 7).ceil();
    return '${now.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  DocumentReference _weekDoc(String weekId) =>
      _firestore.collection('leaderboard').doc(weekId);

  DocumentReference _userScoreDoc(String weekId) =>
      _weekDoc(weekId).collection('scores').doc(_uid);

  // ── Record a quiz result to the leaderboard ────────────────────
  Future<void> recordScore({
    required int score,
    required int totalQuestions,
    required String displayName,
    required String department,
  }) async {
    try {
      if (_uid == null) return;

      final weekId = _currentWeekId;
      final scorePercent = ((score / totalQuestions) * 100).round();
      final docRef = _userScoreDoc(weekId);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'uid': _uid,
          'displayName': displayName,
          'department': department,
          'totalScore': scorePercent,
          'quizzesTaken': 1,
          'weekId': weekId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data() as Map<String, dynamic>;
        final newTotal = (data['totalScore'] ?? 0) + scorePercent;
        final newCount = (data['quizzesTaken'] ?? 0) + 1;

        await docRef.update({
          'displayName': displayName,
          'department': department,
          'totalScore': newTotal,
          'quizzesTaken': newCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error recording leaderboard score: $e');
    }
  }

  // ── Fetch top 50 for current week ──────────────────────────────
  Future<List<LeaderboardEntry>> getWeeklyLeaderboard() async {
    try {
      final weekId = _currentWeekId;
      final snapshot = await _weekDoc(weekId)
          .collection('scores')
          .orderBy('totalScore', descending: true)
          .limit(50)
          .get();

      return _mapToEntries(snapshot.docs);
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return [];
    }
  }

  // ── Get current user's rank this week ─────────────────────────
  Future<LeaderboardEntry?> getMyRank() async {
    try {
      if (_uid == null) return null;
      final weekId = _currentWeekId;
      final doc = await _userScoreDoc(weekId).get();
      if (!doc.exists) return null;

      // Count how many users scored higher
      final data = doc.data() as Map<String, dynamic>;
      final myScore = data['totalScore'] ?? 0;

      final higherSnapshot = await _weekDoc(weekId)
          .collection('scores')
          .where('totalScore', isGreaterThan: myScore)
          .count()
          .get();

      final rank = (higherSnapshot.count ?? 0) + 1;
      final quizzesTaken = data['quizzesTaken'] ?? 1;

      return LeaderboardEntry(
        uid: _uid!,
        displayName: data['displayName'] ?? 'You',
        department: data['department'] ?? '',
        totalScore: myScore,
        quizzesTaken: quizzesTaken,
        averageScore: myScore / quizzesTaken,
        rank: rank,
      );
    } catch (e) {
      debugPrint('Error fetching my rank: $e');
      return null;
    }
  }

  // ── Week label for display (e.g. "Mar 3 – Mar 9") ─────────────
  String get currentWeekLabel {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[monday.month - 1]} ${monday.day} – ${months[sunday.month - 1]} ${sunday.day}';
  }

  // ── Map Firestore docs to LeaderboardEntry list ────────────────
  List<LeaderboardEntry> _mapToEntries(
      List<QueryDocumentSnapshot> docs) {
    return docs.asMap().entries.map((entry) {
      final rank = entry.key + 1;
      final data = entry.value.data() as Map<String, dynamic>;
      final quizzesTaken = data['quizzesTaken'] ?? 1;
      final totalScore = data['totalScore'] ?? 0;

      return LeaderboardEntry(
        uid: data['uid'] ?? '',
        displayName: data['displayName'] ?? 'Anonymous',
        department: data['department'] ?? '',
        totalScore: totalScore,
        quizzesTaken: quizzesTaken,
        averageScore: totalScore / quizzesTaken,
        rank: rank,
      );
    }).toList();
  }
}