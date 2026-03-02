// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import 'profile_check_wrapper.dart';
import '../../services/connectivity_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _connectivityService = ConnectivityService();
  bool _isLoading = false;

  void _showErrorSnackBar(String message) {
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

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter both email and password");
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

      // Attempt sign in
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        // Navigate to ProfileCheckWrapper which will determine next screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileCheckWrapper()),
          (route) => false,
        );
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
          message = "Incorrect username or password";
          break;
        case 'wrong-password':
          message = "Incorrect username or password";
          break;
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

  Future<void> _sendResetEmail(String email) async {
    try {
      // Check internet connection
      final hasInternet = await _connectivityService.hasInternetConnection();
      
      if (!hasInternet) {
        if (mounted) {
          _showErrorSnackBar("An error occurred, please try again");
        }
        return;
      }

      await _auth.sendPasswordResetEmail(email: email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset link sent to $email'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      if (mounted) {
        _showErrorSnackBar("An error occurred, please try again");
      }
    }
  }

  void _showForgotPasswordSheet() {
    final resetController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset Password',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Enter your email to receive a reset link.'),
            const SizedBox(height: 15),
            TextField(
              controller: resetController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                onPressed: () async {
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
                child: const Text('Send Reset Link', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: -15,
            right: -15,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bookillustration1.png', 
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
                    'assets/images/bookillustration1.png',
                    height: 210,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome Back!',
                    style: GoogleFonts.poppins(
                      fontSize: 26, 
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900
                    ),
                  ),
                  Text(
                    'Log in to continue your preparation',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 35),
                  
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
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
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordSheet,
                      child: Text('Forgot Password?', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Log In', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const SignUpScreen()),
                          );
                        },
                        child: Text("Sign Up", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
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