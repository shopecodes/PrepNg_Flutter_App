// lib/screens/auth/profile_check_wrapper.dart

import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../scope_selection_screen.dart';
import 'complete_profile_screen.dart';

class ProfileCheckWrapper extends StatelessWidget {
  const ProfileCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return FutureBuilder<bool>(
      future: userService.isProfileComplete(),
      builder: (context, snapshot) {
        // Show loading while checking profile status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        }

        // If profile is complete, go to Scope Selection
        // Otherwise, show Complete Profile screen
        final isComplete = snapshot.data ?? false;

        if (isComplete) {
          return const ScopeSelectionScreen();
        } else {
          return const CompleteProfileScreen();
        }
      },
    );
  }
}