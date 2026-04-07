// lib/services/offline_service.dart
//
// Central service that manages:
//   1. "Has ever been online" flag — so we can show a proper message
//      to users who have NEVER opened the app with internet
//   2. A simple write queue for streaks/progress/bookmarks that
//      failed offline — retried on next online session

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineService {
  static const _kHasEverBeenOnline = 'has_ever_been_online';
  static const _kPendingWrites = 'offline_pending_writes';

  // ── Call this any time a Firestore read succeeds ───────────────
  // Sets a permanent flag so we know the user has had internet at least once.
  static Future<void> markOnline() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kHasEverBeenOnline) != true) {
      await prefs.setBool(_kHasEverBeenOnline, true);
      debugPrint('✅ First online session recorded');
    }
  }

  // ── Check if user has ever successfully connected ──────────────
  static Future<bool> hasEverBeenOnline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHasEverBeenOnline) ?? false;
  }

  // ── Queue a failed write for retry ─────────────────────────────
  // Each write is stored as JSON: { collection, docId, data, merge }
  static Future<void> queueWrite({
    required String collection,
    String? docId, // null = .add(), non-null = .set()
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingWrites) ?? '[]';
      final List<dynamic> queue = json.decode(raw);

      queue.add({
        'collection': collection,
        'docId': docId,
        'data': data,
        'merge': merge,
        'queuedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await prefs.setString(_kPendingWrites, json.encode(queue));
      debugPrint('📝 Write queued for $collection (${queue.length} pending)');
    } catch (e) {
      debugPrint('❌ Failed to queue write: $e');
    }
  }

  // ── Flush all queued writes — call on app launch when online ───
  static Future<void> flushPendingWrites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingWrites) ?? '[]';
      final List<dynamic> queue = json.decode(raw);

      if (queue.isEmpty) return;
      debugPrint('🔄 Flushing ${queue.length} pending writes...');

      final firestore = FirebaseFirestore.instance;
      final List<dynamic> failed = [];

      for (final item in queue) {
        try {
          final collection = item['collection'] as String;
          final docId = item['docId'] as String?;
          final data = Map<String, dynamic>.from(item['data'] as Map);
          final merge = item['merge'] as bool? ?? false;

          // Replace sentinel strings with real Firestore values
          data.forEach((key, value) {
            if (value == '__serverTimestamp__') {
              data[key] = FieldValue.serverTimestamp();
            }
          });

          if (docId != null) {
            await firestore
                .collection(collection)
                .doc(docId)
                .set(data, SetOptions(merge: merge));
          } else {
            await firestore.collection(collection).add(data);
          }

          debugPrint('✅ Flushed write to $collection');
        } catch (e) {
          debugPrint('❌ Write flush failed, keeping in queue: $e');
          failed.add(item);
        }
      }

      await prefs.setString(_kPendingWrites, json.encode(failed));
      debugPrint('✅ Flush complete — ${failed.length} still pending');
    } catch (e) {
      debugPrint('❌ Error flushing writes: $e');
    }
  }

  // ── How many writes are pending ────────────────────────────────
  static Future<int> pendingWriteCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingWrites) ?? '[]';
    final List<dynamic> queue = json.decode(raw);
    return queue.length;
  }
}