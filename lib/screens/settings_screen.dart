// lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prep_ng/screens/auth/login_screen.dart';
import '../../services/user_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _userService = UserService();
  final _connectivityService = ConnectivityService();
  final _nameController = TextEditingController();
  
  UserModel? _userProfile;
  String _selectedDept = 'Science';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  final List<Map<String, dynamic>> _departments = [
    {'name': 'Science', 'icon': Icons.science_outlined, 'color': Colors.blue},
    {'name': 'Arts', 'icon': Icons.palette_outlined, 'color': Colors.purple},
    {'name': 'Commercial', 'icon': Icons.business_outlined, 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final profile = await _userService.getUserProfile();
      
      if (profile != null && mounted) {
        setState(() {
          _userProfile = profile;
          _nameController.text = profile.displayName ?? '';
          _selectedDept = profile.department ?? 'Science';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading profile: $e', isError: true);
      }
    }
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

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Name cannot be empty', isError: true);
      return;
    }

    if (_nameController.text.trim().length < 3) {
      _showSnackBar('Name must be at least 3 characters', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await _userService.updateProfile(
        displayName: _nameController.text.trim(),
        department: _selectedDept,
      );

      if (success && mounted) {
        await _loadUserProfile(); // Reload profile
        setState(() {
          _isEditing = false;
        });
        _showSnackBar('Profile updated successfully!');
      } else {
        _showSnackBar('Failed to update profile', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEditing() {
    setState(() {
      _nameController.text = _userProfile?.displayName ?? '';
      _selectedDept = _userProfile?.department ?? 'Science';
      _isEditing = false;
    });
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _performLogout();
    }
  }

  Future<void> _performLogout() async {
    try {
      // Check internet connection before logout
      final hasInternet = await _connectivityService.hasInternetConnection();
      
      if (!mounted) return;
      
      if (!hasInternet) {
        _showSnackBar(
          'An error occurred, please check your internet connection and try again',
          isError: true,
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );

      // Perform logout
      await FirebaseAuth.instance.signOut();
      
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog if open
      Navigator.of(context).pop();
      
      _showSnackBar(
        'An error occurred, please check your internet connection and try again',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _cancelEditing,
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                  const SizedBox(height: 15),
                  
                  // Email Display (Read-only)
                  Text(
                    _userProfile?.email ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Name Input
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'User Name',
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
                    onChanged: (value) {
                      if (!_isEditing) {
                        setState(() => _isEditing = true);
                      }
                    },
                  ),
                  const SizedBox(height: 30),

                  // Department Selection
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Department',
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
                          _isEditing = true;
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

                  const SizedBox(height: 30),

                  // Save Button (only visible when editing)
                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout),
                      label: Text(
                        'Logout',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade700, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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