// lib/screens/auth/email_verification_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_check_wrapper.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  Timer? _checkTimer;
  bool _isResending = false;
  bool _resentSuccess = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color _bgColor = Color(0xFFF0F9F4);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    // Poll every 4 seconds — auto-navigate when verified
    _checkTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _auth.currentUser?.reload();
      if (_auth.currentUser?.emailVerified == true) {
        _checkTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const ProfileCheckWrapper()),
            (route) => false,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _cooldownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade700 : _accentGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _resendVerification() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() => _isResending = true);

    try {
      await _auth.currentUser?.sendEmailVerification();
      if (mounted) {
        setState(() {
          _resentSuccess = true;
          _isResending = false;
          _resendCooldown = 60;
        });
        _cooldownTimer =
            Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) { timer.cancel(); return; }
          setState(() {
            _resendCooldown--;
            if (_resendCooldown <= 0) {
              timer.cancel();
              _resentSuccess = false;
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
        _showSnackBar('Failed to resend. Please try again.', isError: true);
      }
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    Text(
                      'Check Your\nEmail 📬',
                      style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _darkGreen,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'One last step before you get started',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: _accentGreen, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _accentGreen.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(Icons.mark_email_unread_rounded,
                            size: 50, color: _accentGreen),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'We sent a verification link to:',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Email display
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _bgColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.email_outlined,
                                    size: 18, color: _accentGreen),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _darkGreen,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Click the link in that email to activate your account. This page will update automatically once verified.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Auto-checking indicator
                          Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _accentGreen),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Waiting for verification...',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: _accentGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SPAM FOLDER REMINDER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.orange.shade700,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Can\'t find the email?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Check your spam or junk folder. Sometimes verification emails end up there.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: _resendCooldown > 0 ? null : _resendVerification,
                      child: Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _resendCooldown > 0
                              ? _accentGreen.withValues(alpha: 0.4)
                              : _accentGreen,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _accentGreen.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isResending
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  _resentSuccess
                                      ? '✓ Sent! Resend in ${_resendCooldown}s'
                                      : _resendCooldown > 0
                                          ? 'Resend in ${_resendCooldown}s'
                                          : 'Resend Verification Email',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Wrong account link
                    Center(
                      child: GestureDetector(
                        onTap: _signOut,
                        child: Text(
                          'Wrong account? Sign out',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}