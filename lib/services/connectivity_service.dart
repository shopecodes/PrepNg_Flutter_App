// lib/services/connectivity_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single global key registered in main.dart on MaterialApp.scaffoldMessengerKey.
/// This lets ConnectivityService show snackbars without needing a BuildContext.
///
/// In main.dart add:
///   scaffoldMessengerKey: connectivityScaffoldKey,
final GlobalKey<ScaffoldMessengerState> connectivityScaffoldKey =
    GlobalKey<ScaffoldMessengerState>();

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity.
  /// DNS lookup is capped at 10 seconds.
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none) ||
          connectivityResult.isEmpty) {
        return false;
      }

      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 10));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Wraps any async operation with a 10-second timeout.
  /// If it times out or fails, shows a snackbar with a Retry button and returns null.
  /// No BuildContext needed — uses [connectivityScaffoldKey] globally.
  ///
  /// Usage:
  ///   final result = await _connectivityService.runWithTimeout(
  ///     operation: () => myFirestoreCall(),
  ///     onRetry: _loadData,
  ///   );
  ///   if (result == null) return;
  Future<T?> runWithTimeout<T>({
    required Future<T> Function() operation,
    VoidCallback? onRetry,
    String? message,
  }) async {
    try {
      final result = await operation().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw _TimeoutException(),
      );
      return result;
    } on _TimeoutException {
      _showSnackbar(
        message ?? 'Connection is taking too long. Please check your internet.',
        onRetry,
      );
      return null;
    } on SocketException {
      _showSnackbar(
        message ?? 'No internet connection. Please try again.',
        onRetry,
      );
      return null;
    } catch (_) {
      _showSnackbar(
        message ?? 'Something went wrong. Please try again.',
        onRetry,
      );
      return null;
    }
  }

  void _showSnackbar(String message, VoidCallback? onRetry) {
    connectivityScaffoldKey.currentState?.hideCurrentSnackBar();
    connectivityScaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A2E1F),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: const Color(0xFF4CAF7D),
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Stream to listen to connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Check connectivity type without actual internet verification
  Future<List<ConnectivityResult>> getConnectivityType() async {
    return await _connectivity.checkConnectivity();
  }
}

class _TimeoutException implements Exception {}