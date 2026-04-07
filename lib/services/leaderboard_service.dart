// lib/services/leaderboard_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'offline_service.dart';

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

  String get _currentWeekId {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final weekNumber =
        ((now.difference(startOfYear).inDays + startOfYear.weekday) / 7)
            .ceil();
    return '${now.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  DocumentReference _weekDoc(String weekId) =>
      _firestore.collection('leaderboard').doc(weekId);

  DocumentReference _userScoreDoc(String weekId) =>
      _weekDoc(weekId).collection('scores').doc(_uid);

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

      try {
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
        // Offline — queue the write for later
        debugPrint('Leaderboard write failed offline — queuing: $e');
        await OfflineService.queueWrite(
          collection: 'leaderboard/$weekId/scores',
          docId: _uid,
          data: {
            'uid': _uid!,
            'displayName': displayName,
            'department': department,
            'totalScore': scorePercent,
            'quizzesTaken': 1,
            'weekId': weekId,
            'updatedAt': '__serverTimestamp__',
          },
          merge: true,
        );
      }
    } catch (e) {
      debugPrint('Error recording leaderboard score: $e');
    }
  }

  // ── Fetch leaderboard — cache first, server on force refresh ──
  //
  // [forceRefresh] = true → always hit server (used by pull-to-refresh)
  // [forceRefresh] = false → try cache first, fall back to server
  Future<List<LeaderboardEntry>> getWeeklyLeaderboard({
    bool forceRefresh = false,
  }) async {
    try {
      final weekId = _currentWeekId;
      final query = _weekDoc(weekId)
          .collection('scores')
          .orderBy('totalScore', descending: true)
          .limit(50);

      QuerySnapshot snapshot;

      if (!forceRefresh) {
        // Try cache first
        try {
          final cached =
              await query.get(const GetOptions(source: Source.cache));
          if (cached.docs.isNotEmpty) {
            debugPrint('📦 Leaderboard from cache');
            await OfflineService.markOnline(); // cache implies past connection
            return _mapToEntries(cached.docs);
          }
        } catch (_) {}
      }

      // Cache empty or force refresh — hit server
      snapshot = await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      await OfflineService.markOnline();
      debugPrint('🌐 Leaderboard from server');
      return _mapToEntries(snapshot.docs);
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return [];
    }
  }

  // ── My rank — cache first ──────────────────────────────────────
  Future<LeaderboardEntry?> getMyRank({bool forceRefresh = false}) async {
    try {
      if (_uid == null) return null;
      final weekId = _currentWeekId;

      DocumentSnapshot doc;

      if (!forceRefresh) {
        try {
          doc = await _userScoreDoc(weekId)
              .get(const GetOptions(source: Source.cache));
          if (!doc.exists) throw Exception('not in cache');
          debugPrint('📦 My rank from cache');
        } catch (_) {
          doc = await _userScoreDoc(weekId)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 10));
        }
      } else {
        doc = await _userScoreDoc(weekId)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
      }

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      final myScore = data['totalScore'] ?? 0;

      // Count users with higher score — requires server
      // If offline, fall back to rank=0 (unknown)
      int rank = 0;
      try {
        final higherSnapshot = await _weekDoc(weekId)
            .collection('scores')
            .where('totalScore', isGreaterThan: myScore)
            .count()
            .get();
        rank = (higherSnapshot.count ?? 0) + 1;
      } catch (_) {
        rank = 0; // offline — rank unknown
      }

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

  List<LeaderboardEntry> _mapToEntries(List<QueryDocumentSnapshot> docs) {
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