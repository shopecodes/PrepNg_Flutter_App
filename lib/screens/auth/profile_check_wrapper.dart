// lib/screens/auth/profile_check_wrapper.dart

import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../scope_selection_screen.dart';
import 'complete_profile_screen.dart';

class ProfileCheckWrapper extends StatefulWidget {
  const ProfileCheckWrapper({super.key});

  @override
  State<ProfileCheckWrapper> createState() => _ProfileCheckWrapperState();
}

class _ProfileCheckWrapperState extends State<ProfileCheckWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    final userService = UserService();
    final isComplete = await userService.isProfileComplete();

    if (!mounted) return;

    // Navigate immediately — don't wait for next frame or app restart
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => isComplete
            ? const ScopeSelectionScreen()
            : const CompleteProfileScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show spinner while checking
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