// lib/screens/auth/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_check_wrapper.dart';
import '../../services/connectivity_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _connectivityService = ConnectivityService();
  bool _isLoading = false;

  // List of allowed email domains
  final List<String> _allowedDomains = [
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
    'aol.com',
    'protonmail.com',
    'mail.com',
    'zoho.com',
    'yandex.com',
    'gmx.com',
    'live.com',
    'msn.com',
    'me.com',
    'mac.com',
    'yahoo.co.uk',
    'outlook.co.uk',
  ];

  // Helper for consistent SnackBar styling
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Validate email domain
  bool _isValidEmailDomain(String email) {
    if (!email.contains('@')) return false;
    
    final domain = email.split('@').last.toLowerCase();
    return _allowedDomains.contains(domain);
  }

  // Validate email format
  bool _isValidEmailFormat(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar("Please fill in all fields");
      return;
    }

    // Validate email format
    if (!_isValidEmailFormat(email)) {
      _showErrorSnackBar("Please enter a valid email address");
      return;
    }

    // Validate email domain
    if (!_isValidEmailDomain(email)) {
      _showErrorSnackBar(
        "Please use a valid email from providers like Gmail, Yahoo, or Outlook"
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check internet connection first
      final hasInternet = await _connectivityService.hasInternetConnection();
      
      if (!mounted) return;
      
      if (!hasInternet) {
        _showErrorSnackBar("An error occurred, please try again");
        return;
      }

      // Attempt to create account
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (mounted) {
        // Navigate to ProfileCheckWrapper (will show Complete Profile for new users)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileCheckWrapper()),
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
        case 'operation-not-allowed':
          message = "Email/password accounts are not enabled";
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
      // Generic error (likely network related)
      _showErrorSnackBar("An error occurred, please try again");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('PrepNG', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 54, 127, 57),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: -20,
            left: -15,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bookillustration2.png',
                height: 150,
              ),
            ),
          ),

          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Image.asset(
                    'assets/images/bookillustration2.png',
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Join PrepNG Today',
                    style: GoogleFonts.poppins(
                      fontSize: 26, 
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900
                    ),
                  ),
                  Text(
                    'Start your journey to exam success',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 35),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'user@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Min. 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Create Account', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); 
                        },
                        child: Text("Log In", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}