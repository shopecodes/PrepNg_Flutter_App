// lib/screens/auth/profile_check_wrapper.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_service.dart';
import '../../services/purchase_service.dart';
import '../../services/connectivity_service.dart';
import '../scope_selection_screen.dart';
import 'complete_profile_screen.dart';

class ProfileCheckWrapper extends StatefulWidget {
  const ProfileCheckWrapper({super.key});

  @override
  State<ProfileCheckWrapper> createState() => _ProfileCheckWrapperState();
}

class _ProfileCheckWrapperState extends State<ProfileCheckWrapper> {
  static const Color _accentGreen = Color(0xFF4CAF7D);

  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    final userService = UserService();
    final isComplete = await userService.isProfileComplete();

    if (!mounted) return;

    // Navigate first — don't keep user waiting
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => isComplete
            ? const ScopeSelectionScreen()
            : const CompleteProfileScreen(),
      ),
    );

    // Run payment recovery AFTER navigation so it never blocks the UI.
    // If the app was killed while a bank transfer was in progress,
    // this verifies the saved reference and unlocks the subject automatically.
    // Uses a post-frame callback so the new screen is fully mounted first
    // and can show the success snackbar correctly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverPaymentIfNeeded();
    });
  }

  Future<void> _recoverPaymentIfNeeded() async {
    try {
      final purchaseService = PurchaseService();
      final result = await purchaseService.recoverPendingPayment();

      if (!mounted) return;
      if (result == null || !result.success) return;

      // Payment recovered — show snackbar using the global scaffold key
      // so it appears regardless of which screen the user is on
      connectivityScaffoldKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your previous payment was confirmed and your subject is now unlocked! Go to your subject list to access it.',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: _accentGreen,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      debugPrint('Payment recovery error in ProfileCheckWrapper: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5FAF6),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4CAF7D),
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}