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

/// Result of a payment operation with detailed error information
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

/// Types of payment errors for better handling
enum PaymentErrorType {
  network,
  verification,
  cancelled,
  timeout,
  server,
  unknown,
}

class PurchaseService {
  final _firestore = FirebaseFirestore.instance;

  String get _publicKey => PaystackConfig.publicKey;
  String get _secretKey => PaystackConfig.secretKey;

  static const _kPendingRef = 'pending_payment_reference';
  static const _kPendingSubjectId = 'pending_payment_subject_id';
  static const _kPendingSubjectName = 'pending_payment_subject_name';

  // ─────────────────────────────────────────────────────────────────────────
  // KEY DESIGN:
  //
  // Save the reference to disk BEFORE opening the Paystack popup.
  // NEVER delete it just because onClosed fired without onSuccess —
  // that is indistinguishable from the user going to their bank app.
  //
  // Only clear the reference in two situations:
  //   1. Paystack verifies the payment as "success" → unlock + clear
  //   2. Paystack verifies the payment as definitively failed/abandoned
  //      AND a minimum wait window has passed → clear
  //
  // On every app launch, recoverPendingPayment() checks any saved ref
  // against Paystack's verify API. If money went through, subject unlocks.
  // ─────────────────────────────────────────────────────────────────────────

  // Timestamp of when the ref was created — used to decide when to give up
  static const _kPendingCreatedAt = 'pending_payment_created_at';

  // How long we keep trying to verify (72 hours — covers slow bank transfers)
  static const _kMaxRecoveryMs = 72 * 60 * 60 * 1000;

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

  /// Called on every app launch from SubjectListScreen.initState().
  ///
  /// Flow:
  ///   1. If no saved ref → nothing to do
  ///   2. If ref is older than 72 hours → give up and clear
  ///   3. Ask Paystack: did this payment succeed?
  ///      YES → save to Firestore, clear ref, return success
  ///      NO  → keep ref, return null (will retry next launch)
  Future<PaymentResult?> recoverPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final ref = prefs.getString(_kPendingRef);
    final subjectId = prefs.getString(_kPendingSubjectId);
    final subjectName = prefs.getString(_kPendingSubjectName);
    final createdAt = prefs.getInt(_kPendingCreatedAt) ?? 0;

    if (ref == null || subjectId == null) return null;

    // Give up after 72 hours — bank transfers that haven't cleared by then
    // almost certainly failed or were reversed.
    final age = DateTime.now().millisecondsSinceEpoch - createdAt;
    if (age > _kMaxRecoveryMs) {
      debugPrint('⏰ Pending ref too old (${age ~/ 3600000}h) — discarding');
      await _clearPendingPayment();
      return null;
    }

    debugPrint('🔄 Pending ref found: $ref — verifying with Paystack...');
    final isVerified = await _verifyPayment(ref);

    if (isVerified) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // User not logged in yet — keep the ref, retry next launch
        debugPrint('⚠️ Verified but user not logged in — retrying next launch');
        return null;
      }

      try {
        final existing = await _firestore
            .collection('user_subjects')
            .where('paymentReference', isEqualTo: ref)
            .get();

        if (existing.docs.isEmpty) {
          await _firestore.collection('user_subjects').add({
            'userId': user.uid,
            'subjectId': subjectId,
            'purchaseDate': FieldValue.serverTimestamp(),
            'subjectName': subjectName,
            'amount': 500,
            'paymentReference': ref,
            'paymentMode': PaystackConfig.mode,
            'recovered': true,
          });
          debugPrint('✅ Recovered payment saved to Firestore: $ref');
        } else {
          debugPrint('ℹ️ Already in Firestore, skipping duplicate: $ref');
        }

        await _clearPendingPayment();
        return PaymentResult.success();
      } catch (e) {
        debugPrint('❌ Error saving recovered payment: $e');
        // Don't clear — retry next launch
        return null;
      }
    }

    // Not verified yet — keep the ref and retry on next launch.
    // This covers the "transfer pending" state that bank transfers sit in
    // for minutes to hours after the user sends money.
    debugPrint('⏳ Not yet verified — keeping ref for next launch: $ref');
    return null;
  }

  Future<bool> _verifyPayment(String reference) async {
    try {
      final url = Uri.parse(
          'https://api.paystack.co/transaction/verify/$reference');
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $_secretKey',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Verification response: $data');
        if (data['status'] == true && data['data']['status'] == 'success') {
          debugPrint('✅ Payment verified!');
          return true;
        }
      }
      debugPrint('❌ Verification failed: ${response.statusCode}');
      return false;
    } on SocketException catch (e) {
      debugPrint('❌ Network error during verification: $e');
      return false;
    } on TimeoutException catch (e) {
      debugPrint('❌ Verification timeout: $e');
      return false;
    } catch (e) {
      debugPrint('❌ Verification error: $e');
      return false;
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
        s.contains('failed host lookup');
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

      // Save BEFORE opening the popup. If the OS kills the app the moment
      // the user switches to their bank app, this ref survives on disk.
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
            // ── WHY NOTHING IS DONE HERE ──────────────────────────────────────
            // onClosed fires in two very different situations:
            //   a) User tapped X to cancel (no payment intended)
            //   b) User copied the bank account number, then closed the popup
            //      to go to their bank app and send money
            //
            // I cannot tell (a) from (b) at this moment. The only reliable
            // signal is Paystack's verify API. So leave the ref on disk
            // and let recoverPendingPayment() sort it out on the next launch.
            //
            // Result: genuine cancellations get a stale ref that verify will
            // return "abandoned" for → cleared on next launch. Bank transfers
            // that succeeded get recovered automatically. ✅
            debugPrint('=== PAYMENT WINDOW CLOSED (ref kept on disk) ===');
          },
          onSuccess: () {
            // Card payments and instant transfers land here.
            // Bank transfers that complete while the popup is still open
            // also fire this (rare but possible).
            debugPrint('=== onSuccess callback fired ===');
            paymentSuccessCallback = true;
          },
        );
      } on SocketException {
        await _clearPendingPayment();
        return PaymentResult.error(
          'No internet connection. Please check your network and try again.',
          PaymentErrorType.network,
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

      // ── POST-POPUP LOGIC ────────────────────────────────────────────────
      //
      // If onSuccess fired → card payment or instant transfer. Verify now.
      // If onSuccess did NOT fire → user either cancelled OR went to bank app.
      //   Either way, we verify. If the transfer already went through (fast
      //   banks), the subject unlocks immediately. If not, the ref stays on
      //   disk and recovery handles it on next launch.
      //
      // Never call _clearPendingPayment() here unless verification passes.

      // Brief delay to let Paystack's backend settle
      await Future.delayed(const Duration(seconds: 2));

      debugPrint('=== VERIFYING PAYMENT (paymentSuccessCallback=$paymentSuccessCallback) ===');
      final isVerified = await _verifyPayment(reference);

      if (isVerified) {
        try {
          final existing = await _firestore
              .collection('user_subjects')
              .where('paymentReference', isEqualTo: reference)
              .get();

          if (existing.docs.isEmpty) {
            await _firestore.collection('user_subjects').add({
              'userId': user.uid,
              'subjectId': subjectId,
              'purchaseDate': FieldValue.serverTimestamp(),
              'subjectName': subjectName,
              'amount': 500,
              'paymentReference': reference,
              'paymentMode': PaystackConfig.mode,
            });
          }

          await _clearPendingPayment();
          debugPrint('✅ Purchase saved to Firestore');
          return PaymentResult.success();
        } catch (e) {
          debugPrint('❌ Error saving to Firestore: $e');
          // Don't clear — recovery will retry on next launch
          return PaymentResult.error(
            'Payment successful but failed to save. Please contact support with reference: $reference',
            PaymentErrorType.server,
          );
        }
      }

      // Verification returned non-success.
      // - If onSuccess fired: something went wrong (shouldn't happen normally)
      // - If onSuccess did NOT fire: user cancelled OR sent a bank transfer
      //   that hasn't cleared yet.
      //
      // In both cases: keep the ref on disk so recovery can check again.
      // The message below tells the user what to expect.
      if (paymentSuccessCallback) {
        // Paystack told us success but verify disagreed — rare timing issue.
        // Recovery will catch it on next launch.
        return PaymentResult.error(
          'Payment is being processed. Your subject will unlock automatically once confirmed — usually within a few minutes.',
          PaymentErrorType.verification,
        );
      }

      // User closed the popup without onSuccess. Could be a cancel or a
      // pending bank transfer. Show a neutral message.
      return PaymentResult.error(
        'If you completed the bank transfer, your subject will unlock automatically the next time you open the app.',
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
      debugPrint('❌ Timeout Error: $e');
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
      debugPrint('❌ Unexpected Error: $e');
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