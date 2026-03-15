// lib/services/streak_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StreakData {
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastActiveDate;
  final List<DateTime> activeDays; // last 30 days for heatmap

  StreakData({
    required this.currentStreak,
    required this.bestStreak,
    this.lastActiveDate,
    required this.activeDays,
  });

  factory StreakData.empty() => StreakData(
        currentStreak: 0,
        bestStreak: 0,
        lastActiveDate: null,
        activeDays: [],
      );
}

class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference? get _streakDoc {
    if (_uid == null) return null;
    return _firestore.collection('streaks').doc(_uid);
  }

  // ── Call this every time a quiz is completed ───────────────────
  Future<void> recordActivity() async {
    try {
      if (_uid == null) return;

      final today = _dateOnly(DateTime.now());
      final doc = await _streakDoc!.get();

      if (!doc.exists) {
        // First ever activity
        await _streakDoc!.set({
          'currentStreak': 1,
          'bestStreak': 1,
          'lastActiveDate': Timestamp.fromDate(today),
          'activeDays': [Timestamp.fromDate(today)],
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final lastActive = (data['lastActiveDate'] as Timestamp?)?.toDate();
      final lastActiveDay = lastActive != null ? _dateOnly(lastActive) : null;

      // Already recorded today — nothing to update
      if (lastActiveDay != null && lastActiveDay == today) return;

      int currentStreak = data['currentStreak'] ?? 0;
      int bestStreak = data['bestStreak'] ?? 0;

      final yesterday = today.subtract(const Duration(days: 1));

      if (lastActiveDay == yesterday) {
        // Consecutive day — extend streak
        currentStreak++;
      } else {
        // Streak broken — reset
        currentStreak = 1;
      }

      if (currentStreak > bestStreak) bestStreak = currentStreak;

      // Keep activeDays list — append today, trim to last 90 days
      List<dynamic> activeDays = List.from(data['activeDays'] ?? []);
      activeDays.add(Timestamp.fromDate(today));

      final cutoff = today.subtract(const Duration(days: 90));
      activeDays = activeDays.where((t) {
        final date = (t as Timestamp).toDate();
        return date.isAfter(cutoff);
      }).toList();

      await _streakDoc!.update({
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastActiveDate': Timestamp.fromDate(today),
        'activeDays': activeDays,
      });
    } catch (e) {
      debugPrint('Error recording streak activity: $e');
    }
  }

  // ── Fetch streak data for display ─────────────────────────────
  Future<StreakData> getStreakData() async {
    try {
      if (_uid == null) return StreakData.empty();

      final doc = await _streakDoc!.get();
      if (!doc.exists) return StreakData.empty();

      final data = doc.data() as Map<String, dynamic>;

      final activeDays = (data['activeDays'] as List<dynamic>? ?? [])
          .map((t) => _dateOnly((t as Timestamp).toDate()))
          .toList();

      // Validate streak is still alive (user may not have opened app in days)
      int currentStreak = data['currentStreak'] ?? 0;
      final lastActive =
          (data['lastActiveDate'] as Timestamp?)?.toDate();

      if (lastActive != null) {
        final today = _dateOnly(DateTime.now());
        final yesterday = today.subtract(const Duration(days: 1));
        final lastActiveDay = _dateOnly(lastActive);

        // If last activity was before yesterday, streak is broken
        if (lastActiveDay.isBefore(yesterday)) {
          currentStreak = 0;
          // Update Firestore to reflect broken streak
          await _streakDoc!.update({'currentStreak': 0});
        }
      }

      return StreakData(
        currentStreak: currentStreak,
        bestStreak: data['bestStreak'] ?? 0,
        lastActiveDate: lastActive,
        activeDays: activeDays,
      );
    } catch (e) {
      debugPrint('Error fetching streak data: $e');
      return StreakData.empty();
    }
  }

  // ── Helper: strip time, keep date only ────────────────────────
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}