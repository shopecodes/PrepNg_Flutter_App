// lib/screens/auth/welcome_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_services.dart';
import '../../services/connectivity_service.dart';
import '../../services/notification_service.dart';
import 'login_screen.dart';
import 'profile_check_wrapper.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _badgeController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _badgeAnim;

  bool _isGoogleLoading = false;
  bool _imageReady = false; // ← tracks when image is decoded and ready

  static const Color _accentGreen = Color(0xFF4CAF7D);

  // ── Single shared AssetImage so Flutter decodes it only once ─────────────
  static const AssetImage _bgImage = AssetImage(
    'assets/images/beautiful-female-editor-works-book-review-writes-idea-notebook.jpg',
  );

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _badgeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController, curve: Curves.easeOut));
    _badgeAnim =
        CurvedAnimation(parent: _badgeController, curve: Curves.elasticOut);

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _badgeController.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ── Precache the image as soon as the context is available ───────────
    // precacheImage decodes the asset into Flutter's image cache so when
    // _buildBgImage renders it is already in memory — no decode delay.
    precacheImage(_bgImage, context).then((_) {
      if (mounted) setState(() => _imageReady = true);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    connectivityScaffoldKey.currentState?.showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showTimeoutSnackbar() {
    connectivityScaffoldKey.currentState?.showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Connection timed out. Please check your internet.',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A2E1F),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    final navigator = Navigator.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      UserCredential? credential;
      try {
        credential = await authService
            .signInWithGoogle()
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        if (!mounted) return;
        _showTimeoutSnackbar();
        return;
      }

      if (credential == null) return;
      if (!mounted) return;

      await NotificationService().onUserLogin();

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) => const ProfileCheckWrapper()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message =
              'This email is already registered. Please use "Continue with Email" to sign in instead.';
          break;
        case 'network-request-failed':
          message = 'No internet connection. Please try again.';
          break;
        case 'sign_in_canceled':
          return;
        default:
          message = 'Google sign-in failed. Please try again.';
      }
      _showError(message);
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancel') ||
          errorStr.contains('sign_in_canceled')) {
        return;
      }
       _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ── Shared image widget — uses the pre-declared AssetImage constant ───────
  Widget _buildBgImage(BuildContext context) {
    return OverflowBox(
      maxWidth: double.infinity,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 1.3,
        child: Image(
          image: _bgImage, // ← reuses the already-decoded cache entry
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          // Show nothing (transparent) while image is still decoding
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final double blurStartY = screenHeight * 0.70;

    return Scaffold(
      // ── Show a solid background colour while the image is loading ─────
      backgroundColor: const Color(0xFF063D35),
      body: Stack(
        children: [
          // Only render the image layers once the image is decoded
          if (_imageReady) ...[
            Positioned.fill(child: _buildBgImage(context)),
            Positioned.fill(
              child: ClipRect(
                clipper: _TopClipper(fromY: blurStartY),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: _buildBgImage(context),
                ),
              ),
            ),
          ],

          // ── LAYER 3: Dark gradient overlay ──────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.65, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                    const Color(0xFF0A3D2E).withValues(alpha: 0.82),
                    const Color(0xFF063D35),
                  ],
                ),
              ),
            ),
          ),

          // ── LAYER 4: Foreground content ──────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // PrepNG badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      ScaleTransition(
                        scale: _badgeAnim,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1),
                          ),
                          child: Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF7D),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('PrepNG',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ace your\nexams.',
                            style: GoogleFonts.poppins(
                              fontSize: 46,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.05,
                              letterSpacing: -1,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'JAMB & WAEC prep, built for Nigerian students.',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Feature row 1 — sharp background
                          _FeatureRow(
                            icon: Icons.school_rounded,
                            text:
                                '57 subjects across JAMB & WAEC — all based on the official current syllabus',
                          ),
                          const SizedBox(height: 10),
                          // Feature rows 2 & 3 — blurred background
                          _FeatureRow(
                            icon: Icons.emoji_events_rounded,
                            text:
                                'Compete on the weekly leaderboard and track your streak every day',
                          ),
                          const SizedBox(height: 10),
                          _FeatureRow(
                            icon: Icons.bolt_rounded,
                            text:
                                'Daily challenge, mock exams, and 120+ questions per subject — all in one app',
                          ),

                          const SizedBox(height: 32),

                          // Continue with Google
                          GestureDetector(
                            onTap: _isGoogleLoading
                                ? null
                                : _handleGoogleSignIn,
                            child: Container(
                              width: double.infinity,
                              height: 58,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.18),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isGoogleLoading
                                    ? SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: _accentGreen,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration:
                                                const BoxDecoration(
                                              image: DecorationImage(
                                                image: NetworkImage(
                                                    'https://www.google.com/favicon.ico'),
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Continue with Google',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1A2E1F),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Continue with Email
                          GestureDetector(
                            onTap: _isGoogleLoading
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const LoginScreen()),
                                    ),
                            child: Container(
                              width: double.infinity,
                              height: 58,
                              decoration: BoxDecoration(
                                color: _accentGreen,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accentGreen
                                        .withValues(alpha: 0.45),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.email_outlined,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Continue with Email',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Center(
                            child: Text(
                              'By continuing, you agree to our Terms & Privacy Policy',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom clipper — shows only the portion below fromY ──────────────────────
class _TopClipper extends CustomClipper<Rect> {
  final double fromY;
  const _TopClipper({required this.fromY});

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, fromY, size.width, size.height - fromY);

  @override
  bool shouldReclip(_TopClipper old) => old.fromY != fromY;
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4CAF7D), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}