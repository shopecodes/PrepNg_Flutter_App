import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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

  /// Verify payment with Paystack API
  Future<bool> _verifyPayment(String reference) async {
    try {
      final url = Uri.parse('https://api.paystack.co/transaction/verify/$reference');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Payment verification timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Verification Response: $data');

        if (data['status'] == true && data['data']['status'] == 'success') {
          debugPrint('✅ Payment verified successfully! (${PaystackConfig.mode} mode)');
          return true;
        }
      }

      debugPrint('❌ Payment verification failed');
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

  /// Main payment function with comprehensive error handling
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
        PaymentErrorType.unknown,
      );
    }

    if (!context.mounted) {
      return PaymentResult.error(
        'Screen closed during payment',
        PaymentErrorType.cancelled,
      );
    }

    try {
      final reference = 'PAY_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('=== PAYMENT STARTED (${PaystackConfig.mode} MODE) ===');
      debugPrint('Reference: $reference');

      bool paymentCancelled = false;
      bool paymentSuccessCallback = false;

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
        },
        onSuccess: () {
          debugPrint('=== onSuccess callback fired ===');
          paymentSuccessCallback = true;
        },
      );

      if (paymentCancelled && !paymentSuccessCallback) {
        return PaymentResult.error('Payment was cancelled', PaymentErrorType.cancelled);
      }

      await Future.delayed(const Duration(seconds: 2));

      debugPrint('=== VERIFYING PAYMENT ===');
      final isVerified = await _verifyPayment(reference);

      if (isVerified) {
        try {
          await _firestore.collection('user_subjects').add({
            'userId': user.uid,
            'subjectId': subjectId,
            'purchaseDate': FieldValue.serverTimestamp(),
            'subjectName': subjectName,
            'amount': 500,
            'paymentReference': reference,
            'paymentMode': PaystackConfig.mode,
          });
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
        'Payment could not be verified. Please check your transaction history.',
        PaymentErrorType.verification,
      );
    } on SocketException catch (e) {
      debugPrint('❌ Network Error: $e');
      return PaymentResult.error(
        'Unable to connect to payment service. Please check your internet connection and try again.',
        PaymentErrorType.network,
      );
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout Error: $e');
      return PaymentResult.error(
        'Payment request timed out. Please check your internet connection and try again.',
        PaymentErrorType.timeout,
      );
    } on HttpException catch (e) {
      debugPrint('❌ HTTP Error: $e');
      return PaymentResult.error(
        'Payment service is temporarily unavailable. Please try again in a few moments.',
        PaymentErrorType.server,
      );
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');

      final errorString = e.toString().toLowerCase();
      if (errorString.contains('connection') ||
          errorString.contains('socket') ||
          errorString.contains('network') ||
          errorString.contains('refused')) {
        return PaymentResult.error(
          'Unable to connect to payment service. Please check your internet connection and try again.',
          PaymentErrorType.network,
        );
      }

      return PaymentResult.error(
        'An unexpected error occurred. Please try again.',
        PaymentErrorType.unknown,
      );
    }
  }

  Future<bool> hasAccess(String subjectId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Check if subject is free in Firestore first
      final subjectDoc = await _firestore.collection('subjects').doc(subjectId).get();
      if (subjectDoc.exists && subjectDoc.data()?['isFree'] == true) {
        return true;
      }

      // Otherwise check if user has purchased it
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

  /// Returns IDs of all subjects the user can access —
  /// both purchased subjects AND subjects marked as free in Firestore
  Future<Set<String>> getPurchasedSubjectIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      // Run both queries in parallel for efficiency
      final results = await Future.wait([
        // Get subjects the user has purchased
        _firestore
            .collection('user_subjects')
            .where('userId', isEqualTo: user.uid)
            .get(),
        // Get all subjects marked as free
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

      // Combine both sets — user has access to purchased + free subjects
      return {...purchasedIds, ...freeIds};
    } catch (e) {
      debugPrint("Error fetching purchases: $e");
      return {};
    }
  }

  Future<void> mockPurchase(String subjectId, String subjectName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("Error: User must be logged in");
      return;
    }

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