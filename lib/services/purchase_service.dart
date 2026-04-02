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

  // ✅ FIXED: This flag is now set inside onClosed/onSuccess callbacks,
  // NOT after openPaystackPopup() returns. Here's why that matters:
  //
  // When the user taps "Pay with Transfer" and copies the account number,
  // then switches to their bank app — Android may kill this app to free memory.
  // In that case, openPaystackPopup() never returns, so any code after it
  // never runs. But onClosed fires as soon as the user interacts with the
  // Paystack page, which means the flag gets saved to disk before the user
  // even leaves the app. On next launch, recovery sees popupOpened=true
  // and calls Paystack's verify API to check if the transfer went through.
  static const _kPendingPopupOpened = 'pending_payment_popup_opened';

  Future<void> _savePendingPayment({
    required String reference,
    required String subjectId,
    required String subjectName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingRef, reference);
    await prefs.setString(_kPendingSubjectId, subjectId);
    await prefs.setString(_kPendingSubjectName, subjectName);
    await prefs.setBool(_kPendingPopupOpened, false);
    debugPrint('💾 Pending payment saved (popup not yet opened): $reference');
  }

  Future<void> _markPopupOpened() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPendingPopupOpened, true);
    debugPrint('✅ Paystack popup confirmed open — reference is live');
  }

  Future<void> _clearPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingRef);
    await prefs.remove(_kPendingSubjectId);
    await prefs.remove(_kPendingSubjectName);
    await prefs.remove(_kPendingPopupOpened);
    debugPrint('🗑️ Pending payment cleared');
  }

  /// Called on every app launch from SubjectListScreen.initState().
  ///
  /// Recovery runs when:
  ///   1. A saved reference exists
  ///   2. _kPendingPopupOpened == true (user interacted with Paystack popup)
  ///   3. Paystack confirms the payment as successful
  Future<PaymentResult?> recoverPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final ref = prefs.getString(_kPendingRef);
    final subjectId = prefs.getString(_kPendingSubjectId);
    final subjectName = prefs.getString(_kPendingSubjectName);
    final popupWasOpened = prefs.getBool(_kPendingPopupOpened) ?? false;

    if (ref == null || subjectId == null) return null;

    if (!popupWasOpened) {
      debugPrint('⚠️ Stale ref (popup never opened) — discarding: $ref');
      await _clearPendingPayment();
      return null;
    }

    debugPrint('🔄 Live pending ref found: $ref — verifying with Paystack...');
    final isVerified = await _verifyPayment(ref);

    if (isVerified) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
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
        return null;
      }
    }

    debugPrint('⏳ Not yet verified — keeping ref for next launch: $ref');
    return null;
  }

  Future<bool> _verifyPayment(String reference) async {
    try {
      final url = Uri.parse(
          'https://api.paystack.co/transaction/verify/$reference');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Payment verification timed out'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Verification Response: $data');
        if (data['status'] == true && data['data']['status'] == 'success') {
          debugPrint('✅ Payment verified!');
          return true;
        }
      }
      debugPrint('❌ Verification failed');
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
          'You must be logged in to purchase subjects', PaymentErrorType.unknown);
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

      bool paymentCancelled = false;
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
            debugPrint('=== PAYMENT WINDOW CLOSED ===');
            paymentCancelled = true;
            // ✅ Mark popup opened here — this fires as soon as the user
            // interacts with the Paystack page. If the user copies the bank
            // account number and switches to their bank app (causing Android
            // to kill this app), this flag is already on disk. Recovery will
            // then verify the reference on next app launch.
            _markPopupOpened();
          },
          onSuccess: () {
            debugPrint('=== onSuccess callback fired ===');
            paymentSuccessCallback = true;
            _markPopupOpened();
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

      if (paymentCancelled && !paymentSuccessCallback) {
        await _clearPendingPayment();
        return PaymentResult.error(
            'Payment was cancelled', PaymentErrorType.cancelled);
      }

      await Future.delayed(const Duration(seconds: 2));

      debugPrint('=== VERIFYING PAYMENT ===');
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
          return PaymentResult.error(
            'Payment successful but failed to save. Please contact support with reference: $reference',
            PaymentErrorType.server,
          );
        }
      }

      return PaymentResult.error(
        'Payment could not be verified. If you completed the transfer, it will be confirmed automatically when you reopen the app.',
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
          'An unexpected error occurred. Please try again.', PaymentErrorType.unknown);
    }
  }

  Future<bool> hasAccess(String subjectId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final subjectDoc =
          await _firestore.collection('subjects').doc(subjectId).get();
      if (subjectDoc.exists && subjectDoc.data()?['isFree'] == true) return true;

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
        _firestore.collection('subjects').where('isFree', isEqualTo: true).get(),
      ]);

      final purchasedIds =
          results[0].docs.map((doc) => doc.data()['subjectId'] as String).toSet();
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