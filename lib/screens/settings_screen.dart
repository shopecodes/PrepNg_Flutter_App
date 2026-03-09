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

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _userService = UserService();
  final _connectivityService = ConnectivityService();
  final _nameController = TextEditingController();

  UserModel? _userProfile;
  String _selectedDept = 'Science';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color palette
  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  final List<Map<String, dynamic>> _departments = [
    {'name': 'Science', 'icon': Icons.science_outlined, 'color': const Color(0xFF4CAF7D)},
    {'name': 'Arts', 'icon': Icons.palette_outlined, 'color': const Color(0xFF9B7FD4)},
    {'name': 'Commercial', 'icon': Icons.business_outlined, 'color': const Color(0xFFE89B4A)},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
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
        _animController.forward();
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
        content: Text(message,
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade700 : _accentGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
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
        await _loadUserProfile();
        setState(() => _isEditing = false);
        _showSnackBar('Profile updated successfully!');
      } else {
        _showSnackBar('Failed to update profile', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.logout_rounded,
                    color: Colors.red.shade600, size: 26),
              ),
              const SizedBox(height: 16),
              Text('Log Out?',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkGreen)),
              const SizedBox(height: 8),
              Text('Are you sure you want to log out of your account?',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.5)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text('Log Out',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) await _performLogout();
  }

  Future<void> _performLogout() async {
    try {
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!mounted) return;
      if (!hasInternet) {
        _showSnackBar('Check your internet connection and try again',
            isError: true);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircularProgressIndicator(
                color: _accentGreen, strokeWidth: 2.5),
          ),
        ),
      );

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('Check your internet connection and try again',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF7D), Color(0xFF2E8B57)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentGreen.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 28),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Settings',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_isEditing)
                      GestureDetector(
                        onTap: _cancelEditing,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: _accentGreen, strokeWidth: 2.5))
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Profile Card ───────────────────────
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: _accentGreen
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _accentGreen, width: 2.5),
                                    ),
                                    child: Icon(Icons.school_rounded,
                                        size: 32, color: _accentGreen),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _userProfile?.displayName ?? 'User',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: _darkGreen,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _userProfile?.email ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _accentGreen
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _userProfile?.department ??
                                                'Science',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _accentGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Edit Profile label ─────────────────
                            Text(
                              'EDIT PROFILE',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _accentGreen,
                                letterSpacing: 2,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ── Name input card ────────────────────
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'User Name',
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.grey.shade500,
                                      fontSize: 14),
                                  prefixIcon: Icon(Icons.person_outline,
                                      color: _accentGreen, size: 20),
                                  filled: true,
                                  fillColor: _bgColor,
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
                                onChanged: (value) {
                                  if (!_isEditing) {
                                    setState(() => _isEditing = true);
                                  }
                                },
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Department label ───────────────────
                            Text(
                              'DEPARTMENT',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _accentGreen,
                                letterSpacing: 2,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ── Department cards ───────────────────
                            ...(_departments.map((dept) {
                              final isSelected =
                                  _selectedDept == dept['name'];
                              final color = dept['color'] as Color;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDept = dept['name'];
                                    _isEditing = true;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? color.withValues(alpha: 0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? color
                                          : Colors.grey.shade200,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color
                                                  .withValues(alpha: 0.15),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                            dept['icon'] as IconData,
                                            color: color,
                                            size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          dept['name'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? color
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle_rounded,
                                            color: color, size: 22),
                                    ],
                                  ),
                                ),
                              );
                            }).toList()),

                            const SizedBox(height: 28),

                            // ── Save Button ────────────────────────
                            if (_isEditing)
                              GestureDetector(
                                onTap: _isSaving ? null : _saveChanges,
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: _isSaving
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
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            'Save Changes',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),

                            // ── Logout Button ──────────────────────
                            GestureDetector(
                              onTap: _confirmLogout,
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.red.shade300, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout_rounded,
                                        color: Colors.red.shade600, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Log Out',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}