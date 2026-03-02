// lib/screens/auth/complete_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_service.dart';
import '../scope_selection_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _userService = UserService();
  String _selectedDept = 'Science'; // Default selection
  bool _isLoading = false;

  final List<Map<String, dynamic>> _departments = [
    {'name': 'Science', 'icon': Icons.science_outlined, 'color': Colors.blue},
    {'name': 'Arts', 'icon': Icons.palette_outlined, 'color': Colors.purple},
    {'name': 'Commercial', 'icon': Icons.business_outlined, 'color': Colors.orange},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Function to save profile to Firebase
  Future<void> _saveProfile() async {
    // Validation
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name', isError: true);
      return;
    }

    if (_nameController.text.trim().length < 3) {
      _showSnackBar('Name must be at least 3 characters', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _userService.completeProfile(
        displayName: _nameController.text.trim(),
        department: _selectedDept,
      );

      if (!mounted) return;

      if (success) {
        // Navigate to Scope Selection Screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ScopeSelectionScreen()),
          (route) => false,
        );
      } else {
        _showSnackBar('Failed to save profile. Please try again.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Complete Your Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Prevent going back
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.green),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Welcome Message
                  Text(
                    'Welcome to PrepNg! 🎓',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Let\'s set up your profile to get started',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Profile Icon (non-interactive)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.shade50,
                      border: Border.all(
                        color: Colors.green.shade700,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.school,
                      size: 60,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Name Input
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'User Name',
                      hintText: 'Enter your preferred user name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 30),

                  // Department Selection
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Your Department',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Department Cards
                  ...(_departments.map((dept) {
                    final isSelected = _selectedDept == dept['name'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDept = dept['name'];
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? dept['color'].withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? dept['color'] : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: dept['color'].withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: dept['color'].withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                dept['icon'],
                                color: dept['color'],
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                dept['name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? dept['color'] : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: dept['color'],
                                size: 28,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList()),

                  const SizedBox(height: 40),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}