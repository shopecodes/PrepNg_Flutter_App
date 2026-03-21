// lib/screens/auth/login_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import 'profile_check_wrapper.dart';
import 'email_verification_screen.dart';
import '../../services/connectivity_service.dart';
import '../../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _connectivityService = ConnectivityService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _sheetOpen = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);
  static const Color _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter both email and password");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!mounted) return;
      if (!hasInternet) {
        _showErrorSnackBar("An error occurred, please try again");
        return;
      }
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        await NotificationService().onUserLogin();
        final user = _auth.currentUser;
        await user?.reload();
        if (!mounted) return;
        if (user != null && !user.emailVerified) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const EmailVerificationScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const ProfileCheckWrapper()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = "Invalid email address";
          break;
        case 'user-disabled':
          message = "This account has been disabled";
          break;
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = "Incorrect username or password";
          break;
        case 'too-many-requests':
          message = "Too many failed attempts. Please try again later";
          break;
        case 'network-request-failed':
          message = "An error occurred, please try again";
          break;
        default:
          message = "An error occurred, please try again";
      }
      _showErrorSnackBar(message);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("An error occurred, please try again");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendResetEmail(String email) async {
    try {
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        if (mounted) _showErrorSnackBar("An error occurred, please try again");
        return;
      }
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reset link sent to $email',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: _accentGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ));
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = "Invalid email address";
          break;
        case 'user-not-found':
          message = "No account found with this email";
          break;
        default:
          message = "An error occurred, please try again";
      }
      _showErrorSnackBar(message);
    } catch (e) {
      if (mounted) _showErrorSnackBar("An error occurred, please try again");
    }
  }

  void _showForgotPasswordSheet() {
    final resetController = TextEditingController();
    setState(() => _sheetOpen = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 28, right: 28, top: 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Reset Password 🔐',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen)),
            const SizedBox(height: 8),
            Text('Enter your email to receive a reset link.',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            TextField(
              controller: resetController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade500, fontSize: 14),
                prefixIcon:
                    Icon(Icons.email_outlined, color: _accentGreen, size: 20),
                filled: true,
                fillColor: _bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accentGreen, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final email = resetController.text.trim();
                if (email.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  await _sendResetEmail(email);
                  if (!mounted) return;
                  navigator.pop();
                } else {
                  _showErrorSnackBar("Please enter your email");
                }
              },
              child: Container(
                width: double.infinity, height: 56,
                decoration: BoxDecoration(
                  color: _accentGreen,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _accentGreen.withValues(alpha: 0.35),
                      blurRadius: 20, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text('Send Reset Link',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // ── Main content ───────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18, color: _darkGreen),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return RadialGradient(
                                center: Alignment.center,
                                radius: 0.55,
                                colors: const [
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              'assets/images/Graduation-cuate.png',
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Text('Welcome\nBack! 👋',
                            style: GoogleFonts.poppins(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: _darkGreen,
                                height: 1.2)),

                        const SizedBox(height: 4),

                        Text('Log in to continue your preparation',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w400)),

                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _cardColor,
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
                            children: [
                              // Email
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.poppins(fontSize: 14),
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.grey.shade500,
                                      fontSize: 14),
                                  prefixIcon: Icon(Icons.email_outlined,
                                      color: _accentGreen, size: 20),
                                  filled: true,
                                  fillColor: _isLoading
                                      ? Colors.grey.shade100
                                      : _bgColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: _accentGreen, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Password
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.poppins(fontSize: 14),
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.grey.shade500,
                                      fontSize: 14),
                                  prefixIcon: Icon(Icons.lock_outline,
                                      color: _accentGreen, size: 20),
                                  suffixIcon: GestureDetector(
                                    onTap: _isLoading
                                        ? null
                                        : () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: _isLoading
                                      ? Colors.grey.shade100
                                      : _bgColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: _accentGreen, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                ),
                              ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _showForgotPasswordSheet,
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero),
                                  child: Text('Forgot Password?',
                                      style: GoogleFonts.poppins(
                                          color: _isLoading
                                              ? Colors.grey.shade400
                                              : _accentGreen,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ),

                              const SizedBox(height: 6),

                              GestureDetector(
                                onTap: _isLoading ? null : _signIn,
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: _isLoading
                                        ? _accentGreen.withValues(alpha: 0.6)
                                        : _accentGreen,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _accentGreen
                                            .withValues(alpha: 0.35),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22, width: 22,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5))
                                        : Text('Log In',
                                            style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account? ",
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade500, fontSize: 14)),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const SignUpScreen()),
                                      ),
                              child: Text("Sign Up",
                                  style: GoogleFonts.poppins(
                                      color: _isLoading
                                          ? Colors.grey.shade400
                                          : _accentGreen,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Blur overlay when forgot password sheet is open ──────
          if (_sheetOpen)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                    color: Colors.black.withValues(alpha: 0.05)),
              ),
            ),
        ],
      ),
    );
  }
}