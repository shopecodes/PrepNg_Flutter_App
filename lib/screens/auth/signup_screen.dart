// lib/screens/auth/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'email_verification_screen.dart';
import '../../services/connectivity_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _connectivityService = ConnectivityService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);
  static const Color _cardColor = Colors.white;

  final List<String> _allowedDomains = [
    'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
    'icloud.com', 'aol.com', 'protonmail.com', 'mail.com',
    'zoho.com', 'yandex.com', 'gmx.com', 'live.com',
    'msn.com', 'me.com', 'mac.com', 'yahoo.co.uk', 'outlook.co.uk',
  ];

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

  bool _isValidEmailDomain(String email) {
    if (!email.contains('@')) return false;
    final domain = email.split('@').last.toLowerCase();
    return _allowedDomains.contains(domain);
  }

  bool _isValidEmailFormat(String email) {
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar("Please fill in all fields");
      return;
    }
    if (!_isValidEmailFormat(email)) {
      _showErrorSnackBar("Please enter a valid email address");
      return;
    }
    if (!_isValidEmailDomain(email)) {
      _showErrorSnackBar(
          "Please use a valid email from providers like Gmail, Yahoo, or Outlook");
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

      final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await userCredential.user?.sendEmailVerification();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const EmailVerificationScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = "This email is already registered. Try logging in.";
          break;
        case 'weak-password':
          message = "The password is too weak. Use at least 6 characters.";
          break;
        case 'invalid-email':
          message = "Invalid email address";
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
                    // Back button
                    GestureDetector(
                      onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: _darkGreen),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return RadialGradient(
                            center: Alignment.center,
                            radius: 2,
                            colors: const [
                              Colors.white, Colors.white, Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(
                          'assets/images/college project-pana.png',
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text('Join PrepNG\nToday 🎓',
                        style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: _darkGreen,
                            height: 1.2)),

                    const SizedBox(height: 10),

                    Text('Start your journey to exam success',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w400)),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20, offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Email — disable when loading
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.poppins(fontSize: 14),
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade500, fontSize: 14),
                              hintText: 'user@gmail.com',
                              hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade300, fontSize: 14),
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
                                borderSide:
                                    BorderSide(color: _accentGreen, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Password — disable when loading
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.poppins(fontSize: 14),
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade500, fontSize: 14),
                              hintText: 'Min. 6 characters',
                              hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade300, fontSize: 14),
                              prefixIcon: Icon(Icons.lock_outline,
                                  color: _accentGreen, size: 20),
                              suffixIcon: GestureDetector(
                                onTap: _isLoading
                                    ? null
                                    : () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey.shade400, size: 20,
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
                                borderSide:
                                    BorderSide(color: _accentGreen, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                          ),

                          const SizedBox(height: 26),

                          GestureDetector(
                            onTap: _isLoading ? null : _signUp,
                            child: Container(
                              width: double.infinity, height: 56,
                              decoration: BoxDecoration(
                                color: _isLoading
                                    ? _accentGreen.withValues(alpha: 0.6)
                                    : _accentGreen,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accentGreen.withValues(alpha: 0.35),
                                    blurRadius: 20, offset: const Offset(0, 8),
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
                                    : Text('Create Account',
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

                    const SizedBox(height: 26),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account? ",
                            style: GoogleFonts.poppins(
                                color: Colors.grey.shade500, fontSize: 14)),
                        GestureDetector(
                          onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                          child: Text("Log In",
                              style: GoogleFonts.poppins(
                                  color: _isLoading
                                      ? Colors.grey.shade400
                                      : _accentGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),
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