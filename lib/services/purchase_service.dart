import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../config/paystack_config.dart';

class PaymentResult {
  final bool success;
  final String? errorMessage;
  final PaymentErrorType? errorType;

  PaymentResult({
    required this.success,
    this.errorMessage,
    this.errorType,
  });

  PaymentResult.success()
      : success = true,
        errorMessage = null,
        errorType = null;

  PaymentResult.error(String message, PaymentErrorType type)
      : success = false,
        errorMessage = message,
        errorType = type;
}

enum PaymentErrorType {
  network,
  verification,
  cancelled,
  timeout,
  server,
  unknown,
  // Used when user had an incomplete payment (copied acc number, never paid)
  // so main.dart can show a reminder snackbar instead of a success snackbar
  incompleteReminder,
}

class PurchaseService {
  final _firestore = FirebaseFirestore.instance;

  String get _publicKey => PaystackConfig.publicKey;
  String get _secretKey => PaystackConfig.secretKey;

  static const _kPendingRef = 'pending_payment_reference';
  static const _kPendingSubjectId = 'pending_payment_subject_id';
  static const _kPendingSubjectName = 'pending_payment_subject_name';
  static const _kPendingCreatedAt = 'pending_payment_created_at';

  // 48 hours — covers Paystack settlement delays and slow bank transfers
  static const _kMaxRecoveryMs = 48 * 60 * 60 * 1000;

  // Lock: prevents race condition when main.dart and SubjectListScreen
  // both call recoverPendingPayment() simultaneously on first navigation
  static bool _recoveryInProgress = false;

  Future<void> _savePendingPayment({
    required String reference,
    required String subjectId,
    required String subjectName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingRef, reference);
    await prefs.setString(_kPendingSubjectId, subjectId);
    await prefs.setString(_kPendingSubjectName, subjectName);
    await prefs.setInt(
        _kPendingCreatedAt, DateTime.now().millisecondsSinceEpoch);
    debugPrint('💾 Pending payment saved: $reference');
  }

  Future<void> _clearPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingRef);
    await prefs.remove(_kPendingSubjectId);
    await prefs.remove(_kPendingSubjectName);
    await prefs.remove(_kPendingCreatedAt);
    debugPrint('🗑️ Pending payment cleared');
  }

  /// Saves the subject unlock to Firestore with 3 automatic retries.
  /// The duplicate check has been removed — references are unique by design
  /// (timestamp-based) so writing directly is safe and avoids the index query
  /// that was causing silent failures.
  Future<bool> _saveSubjectUnlock({
    required String userId,
    required String subjectId,
    required String? subjectName,
    required String reference,
    bool recovered = false,
  }) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await _firestore.collection('user_subjects').add({
          'userId': userId,
          'subjectId': subjectId,
          'purchaseDate': FieldValue.serverTimestamp(),
          'subjectName': subjectName,
          'amount': 500,
          'paymentReference': reference,
          'paymentMode': PaystackConfig.mode,
          if (recovered) 'recovered': true,
        }).timeout(const Duration(seconds: 15));

        debugPrint('✅ Subject saved to Firestore (attempt $attempt): $reference');
        return true;
      } catch (e) {
        debugPrint('❌ Firestore attempt $attempt failed: $e');
        if (attempt < 3) await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return false;
  }

  /// ── RECOVERY ─────────────────────────────────────────────────────────────
  ///
  /// Called from main.dart on every cold start.
  ///
  /// Return values:
  ///   PaymentResult.success()                 → subject unlocked, show green snackbar
  ///   PaymentResult.error(incompleteReminder) → user has a pending payment they
  ///                                             never completed, show amber reminder
  ///   null                                    → nothing to do or retry next launch
  ///
  /// Paystack status handling:
  ///   'success' / 'pending' → unlock subject immediately
  ///   'abandoned'           → keep ref + show reminder (user may still pay)
  ///   'failed'              → only status we clear on — definitive bank rejection
  ///   null                  → network error, keep ref and retry next launch
  Future<PaymentResult?> recoverPendingPayment() async {
    if (_recoveryInProgress) {
      debugPrint('⏳ Recovery already in progress — skipping duplicate call');
      return null;
    }
    _recoveryInProgress = true;
    try {
      return await _doRecovery();
    } finally {
      _recoveryInProgress = false;
    }
  }

  Future<PaymentResult?> _doRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    final ref = prefs.getString(_kPendingRef);
    final subjectId = prefs.getString(_kPendingSubjectId);
    final subjectName = prefs.getString(_kPendingSubjectName);
    final createdAt = prefs.getInt(_kPendingCreatedAt) ?? 0;

    if (ref == null || subjectId == null) {
      debugPrint('ℹ️ No pending payment to recover');
      return null;
    }

    final age = DateTime.now().millisecondsSinceEpoch - createdAt;
    if (age > _kMaxRecoveryMs) {
      debugPrint('⏰ Ref expired (${age ~/ 3600000}h old) — discarding: $ref');
      await _clearPendingPayment();
      return null;
    }

    debugPrint('🔄 Pending ref found (${(age / 60000).toStringAsFixed(1)}min old): $ref');

    // Retry verification up to 3 times to handle temporary network blips
    String? status;
    for (int attempt = 1; attempt <= 3; attempt++) {
      debugPrint('🔁 Verify attempt $attempt/3 for: $ref');
      status = await _getPaymentStatus(ref);
      debugPrint('📊 Attempt $attempt status: $status');
      if (status != null) break;
      if (attempt < 3) await Future.delayed(Duration(seconds: attempt * 3));
    }

    debugPrint('📊 Final Paystack status for $ref: $status');

    // ── Payment confirmed — unlock immediately ────────────────────────────
    if (status == 'success' || status == 'pending') {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ Confirmed but user not logged in — retrying next launch');
        return null;
      }

      final saved = await _saveSubjectUnlock(
        userId: user.uid,
        subjectId: subjectId,
        subjectName: subjectName,
        reference: ref,
        recovered: true,
      );

      if (saved) {
        await _clearPendingPayment();
        debugPrint('✅ Recovery complete: $ref');
        return PaymentResult.success();
      } else {
        debugPrint('❌ Firestore save failed — keeping ref for next launch');
        return null;
      }
    }

    // ── Definitive failure — only status we clear on ──────────────────────
    // 'failed' means the bank explicitly rejected the transfer.
    // This is the ONLY status that guarantees no money moved.
    if (status == 'failed') {
      debugPrint('❌ Payment definitively failed — clearing ref: $ref');
      await _clearPendingPayment();
      return null;
    }

    // ── Abandoned — keep ref, show reminder ──────────────────────────────
    // 'abandoned' means the Paystack popup was closed before payment.
    // BUT the user may still send money after closing — Nigerian bank
    // transfers can be initiated minutes or hours after copying the
    // account number. We keep the ref for the full 48-hour window and
    // show a gentle reminder so the user knows they have an open payment.
    if (status == 'abandoned') {
      debugPrint('⚠️ Status abandoned — keeping ref, showing reminder: $ref');
      return PaymentResult.error(
        'You have an incomplete payment for $subjectName. '
        'If you\'ve already sent the money, your subject will unlock automatically. '
        'Otherwise tap a subject to pay now.',
        PaymentErrorType.incompleteReminder,
      );
    }

    // ── null — network error or ref not yet on Paystack ───────────────────
    // Keep the ref silently — retry next launch.
    debugPrint('⏳ Could not verify after 3 attempts — keeping ref: $ref');
    return null;
  }

  /// Returns raw Paystack status string, or null on network error.
  /// Possible values: 'success' | 'pending' | 'failed' | 'abandoned' | null
  Future<String?> _getPaymentStatus(String reference) async {
    try {
      final url = Uri.parse(
          'https://api.paystack.co/transaction/verify/$reference');
      final response = await http
          .get(url, headers: {
            'Authorization': 'Bearer $_secretKey',
            'Content-Type': 'application/json',
          })
          .timeout(const Duration(seconds: 30));

      debugPrint('Paystack verify HTTP ${response.statusCode} for $reference');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          final txStatus = data['data']['status'] as String?;
          debugPrint('Paystack tx status: $txStatus');
          return txStatus;
        }
        debugPrint('Paystack status:false — message: ${data['message']}');
        return null;
      }

      if (response.statusCode == 404) {
        debugPrint('Paystack 404 — ref not found: $reference');
        return null;
      }

      debugPrint('Paystack unexpected HTTP: ${response.statusCode}');
      return null;
    } on SocketException catch (e) {
      debugPrint('❌ Network error verifying: $e');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout verifying: $e');
      return null;
    } catch (e) {
      debugPrint('❌ Verify error: $e');
      return null;
    }
  }

  bool _isNetworkError(dynamic e) {
    final s = e.toString().toLowerCase();
    return s.contains('connection') ||
        s.contains('socket') ||
        s.contains('network') ||
        s.contains('refused') ||
        s.contains('clientexception') ||
        s.contains('unreachable') ||
        s.contains('errno = 101') ||
        s.contains('errno = 111') ||
        s.contains('errno=101') ||
        s.contains('errno=111') ||
        s.contains('failed host lookup') ||
        s.contains('os error') ||
        s.contains('network is unreachable');
  }

  Future<PaymentResult> payAndUnlock(
    BuildContext context, {
    required String subjectId,
    required String subjectName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "student@prep_ng.com";

    if (user == null) {
      return PaymentResult.error(
          'You must be logged in to purchase subjects',
          PaymentErrorType.unknown);
    }
    if (!context.mounted) {
      return PaymentResult.error(
          'Screen closed during payment', PaymentErrorType.cancelled);
    }

    try {
      final reference = 'PAY_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('=== PAYMENT STARTED (${PaystackConfig.mode} MODE) ===');
      debugPrint('Reference: $reference');

      await _savePendingPayment(
        reference: reference,
        subjectId: subjectId,
        subjectName: subjectName,
      );

      if (!context.mounted) {
        await _clearPendingPayment();
        return PaymentResult.error(
            'Screen closed during payment setup', PaymentErrorType.cancelled);
      }

      bool paymentSuccessCallback = false;

      try {
        await FlutterPaystackPlus.openPaystackPopup(
          publicKey: _publicKey,
          secretKey: _secretKey,
          context: context,
          customerEmail: email,
          amount: "50000",
          reference: reference,
          currency: 'NGN',
          metadata: {
            'subjectId': subjectId,
            'subjectName': subjectName,
            'userId': user.uid,
            'mode': PaystackConfig.mode,
          },
          onClosed: () {
            debugPrint('=== POPUP CLOSED — ref kept on disk ===');
          },
          onSuccess: () {
            debugPrint('=== onSuccess fired ===');
            paymentSuccessCallback = true;
          },
        );
      } on SocketException {
        await _clearPendingPayment();
        return PaymentResult.error(
          'No internet connection. Please check your network and try again.',
          PaymentErrorType.network,
        );
      } on TimeoutException {
        await _clearPendingPayment();
        return PaymentResult.error(
          'Connection timed out. Please check your network and try again.',
          PaymentErrorType.timeout,
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          await _clearPendingPayment();
          return PaymentResult.error(
            'No internet connection. Please check your network and try again.',
            PaymentErrorType.network,
          );
        }
        rethrow;
      }

      await Future.delayed(const Duration(seconds: 2));
      debugPrint('=== VERIFYING (onSuccess=$paymentSuccessCallback) ===');

      final status = await _getPaymentStatus(reference);
      debugPrint('Post-popup status: $status');

      if (status == 'success') {
        final saved = await _saveSubjectUnlock(
          userId: user.uid,
          subjectId: subjectId,
          subjectName: subjectName,
          reference: reference,
        );
        if (saved) {
          await _clearPendingPayment();
          return PaymentResult.success();
        } else {
          return PaymentResult.error(
            'Payment was successful but we couldn\'t save it right now. '
            'Reopen the app and your subject will unlock automatically.',
            PaymentErrorType.server,
          );
        }
      }

      if (status == 'pending') {
        final saved = await _saveSubjectUnlock(
          userId: user.uid,
          subjectId: subjectId,
          subjectName: subjectName,
          reference: reference,
        );
        if (saved) {
          await _clearPendingPayment();
          return PaymentResult.success();
        } else {
          return PaymentResult.error(
            'Your transfer is being processed. Your subject will unlock '
            'automatically when you reopen the app.',
            PaymentErrorType.verification,
          );
        }
      }

      if (status == 'failed') {
        await _clearPendingPayment();
        return PaymentResult.error(
          'Payment was not completed. Please try again.',
          PaymentErrorType.verification,
        );
      }

      // abandoned or null — ref stays on disk for recovery
      return PaymentResult.error(
        'If you completed the bank transfer, your subject will unlock '
        'automatically the next time you open the app.',
        PaymentErrorType.verification,
      );
    } on SocketException catch (e) {
      debugPrint('❌ Network Error: $e');
      await _clearPendingPayment();
      return PaymentResult.error(
        'No internet connection. Please check your network and try again.',
        PaymentErrorType.network,
      );
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout: $e');
      return PaymentResult.error(
        'Payment request timed out. Please check your internet and try again.',
        PaymentErrorType.timeout,
      );
    } on HttpException catch (e) {
      debugPrint('❌ HTTP Error: $e');
      await _clearPendingPayment();
      return PaymentResult.error(
        'Payment service is temporarily unavailable. Please try again later.',
        PaymentErrorType.server,
      );
    } catch (e) {
      debugPrint('❌ Unexpected: $e');
      if (_isNetworkError(e)) {
        await _clearPendingPayment();
        return PaymentResult.error(
          'No internet connection. Please check your network and try again.',
          PaymentErrorType.network,
        );
      }
      return PaymentResult.error(
          'An unexpected error occurred. Please try again.',
          PaymentErrorType.unknown);
    }
  }

  Future<bool> hasAccess(String subjectId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final subjectDoc =
          await _firestore.collection('subjects').doc(subjectId).get();
      if (subjectDoc.exists && subjectDoc.data()?['isFree'] == true) {
        return true;
      }

      final snapshot = await _firestore
          .collection('user_subjects')
          .where('userId', isEqualTo: user.uid)
          .where('subjectId', isEqualTo: subjectId)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking access: $e");
      return false;
    }
  }

  Future<Set<String>> getPurchasedSubjectIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      final results = await Future.wait([
        _firestore
            .collection('user_subjects')
            .where('userId', isEqualTo: user.uid)
            .get(),
        _firestore
            .collection('subjects')
            .where('isFree', isEqualTo: true)
            .get(),
      ]);

      final purchasedIds = results[0]
          .docs
          .map((doc) => doc.data()['subjectId'] as String)
          .toSet();
      final freeIds = results[1].docs.map((doc) => doc.id).toSet();

      return {...purchasedIds, ...freeIds};
    } catch (e) {
      debugPrint("Error fetching purchases: $e");
      return {};
    }
  }

  Future<void> mockPurchase(String subjectId, String subjectName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('user_subjects').add({
        'userId': user.uid,
        'subjectId': subjectId,
        'purchaseDate': FieldValue.serverTimestamp(),
        'subjectName': subjectName,
        'amount': 500,
        'isMock': true,
      });
      debugPrint("Mock purchase successful");
    } catch (e) {
      debugPrint("Mock purchase error: $e");
    }
  }
}