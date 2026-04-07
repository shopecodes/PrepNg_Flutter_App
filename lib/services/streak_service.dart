// lib/services/streak_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'offline_service.dart';

class StreakData {
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastActiveDate;
  final List<DateTime> activeDays;

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

  Future<void> recordActivity() async {
    try {
      if (_uid == null) return;

      final today = _dateOnly(DateTime.now());

      // Try to read from cache first — works offline
      DocumentSnapshot? doc;
      try {
        doc = await _streakDoc!
            .get(const GetOptions(source: Source.cache));
        if (!doc.exists) doc = null;
      } catch (_) {}

      // Try server if cache miss
      if (doc == null) {
        try {
          doc = await _streakDoc!
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          doc = null;
        }
      }

      if (doc == null || !doc.exists) {
        // First activity ever — write with queue fallback
        await _writeStreak({
          'currentStreak': 1,
          'bestStreak': 1,
          'lastActiveDate': FieldValue.serverTimestamp(),
          'activeDays': [Timestamp.fromDate(today)],
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final lastActive =
          (data['lastActiveDate'] as Timestamp?)?.toDate();
      final lastActiveDay =
          lastActive != null ? _dateOnly(lastActive) : null;

      if (lastActiveDay != null && lastActiveDay == today) return;

      int currentStreak = data['currentStreak'] ?? 0;
      int bestStreak = data['bestStreak'] ?? 0;
      final yesterday = today.subtract(const Duration(days: 1));

      if (lastActiveDay == yesterday) {
        currentStreak++;
      } else {
        currentStreak = 1;
      }

      if (currentStreak > bestStreak) bestStreak = currentStreak;

      List<dynamic> activeDays = List.from(data['activeDays'] ?? []);
      activeDays.add(Timestamp.fromDate(today));
      final cutoff = today.subtract(const Duration(days: 90));
      activeDays = activeDays.where((t) {
        final date = (t as Timestamp).toDate();
        return date.isAfter(cutoff);
      }).toList();

      await _writeStreak({
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastActiveDate': FieldValue.serverTimestamp(),
        'activeDays': activeDays,
      });
    } catch (e) {
      debugPrint('Error recording streak activity: $e');
    }
  }

  // ── Write with offline queue fallback ─────────────────────────
  Future<void> _writeStreak(Map<String, dynamic> data) async {
    try {
      await _streakDoc!.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Streak write failed — queuing: $e');
      // Replace FieldValue with sentinel for queue storage
      final queueData = Map<String, dynamic>.from(data);
      queueData['lastActiveDate'] = '__serverTimestamp__';
      // activeDays with Timestamps can't be JSON-serialized — convert to ms
      if (queueData['activeDays'] is List) {
        queueData['activeDays'] = (queueData['activeDays'] as List)
            .map((t) => t is Timestamp
                ? t.toDate().millisecondsSinceEpoch
                : t)
            .toList();
      }
      await OfflineService.queueWrite(
        collection: 'streaks',
        docId: _uid,
        data: queueData,
        merge: true,
      );
    }
  }

  // ── Fetch streak — cache first ─────────────────────────────────
  Future<StreakData> getStreakData() async {
    try {
      if (_uid == null) return StreakData.empty();

      DocumentSnapshot? doc;

      // Try cache first
      try {
        doc = await _streakDoc!
            .get(const GetOptions(source: Source.cache));
        if (!doc.exists) {
          doc = null;
        } else {
          debugPrint('📦 Streak from cache');
        }
      } catch (_) {}

      // Fall back to server
      if (doc == null) {
        try {
          doc = await _streakDoc!
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 10));
          await OfflineService.markOnline();
          debugPrint('🌐 Streak from server');
        } catch (_) {
          return StreakData.empty();
        }
      }

      if (!doc.exists) return StreakData.empty();

      final data = doc.data() as Map<String, dynamic>;

      final activeDays = (data['activeDays'] as List<dynamic>? ?? [])
          .map((t) => _dateOnly((t as Timestamp).toDate()))
          .toList();

      int currentStreak = data['currentStreak'] ?? 0;
      final lastActive =
          (data['lastActiveDate'] as Timestamp?)?.toDate();

      if (lastActive != null) {
        final today = _dateOnly(DateTime.now());
        final yesterday = today.subtract(const Duration(days: 1));
        final lastActiveDay = _dateOnly(lastActive);

        if (lastActiveDay.isBefore(yesterday)) {
          currentStreak = 0;
          // Best-effort update — don't block on failure
          _streakDoc!.update({'currentStreak': 0}).catchError((_) {});
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

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}