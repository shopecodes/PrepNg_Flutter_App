import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../provider/theme_provider.dart';
import '../services/auth_services.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import 'auth/welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accentGreen = Color(0xFF4CAF7D);

  final _userService = UserService();
  final _connectivityService = ConnectivityService();
  final _nameController = TextEditingController();
  final _deleteConfirmController = TextEditingController();

  final List<Map<String, dynamic>> _departments = [
    {
      'name': 'Science',
      'icon': Icons.science_outlined,
      'color': const Color(0xFF4CAF7D),
    },
    {
      'name': 'Arts',
      'icon': Icons.palette_outlined,
      'color': const Color(0xFF9B7FD4),
    },
    {
      'name': 'Commercial',
      'icon': Icons.business_outlined,
      'color': const Color(0xFFE89B4A),
    },
  ];

  UserModel? _userProfile;
  String _selectedDept = 'Science';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _isDeletingAccount = false;
  bool _isProgressDialogVisible = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deleteConfirmController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final profile = await _userService.getUserProfile();
      if (!mounted) return;

      setState(() {
        _userProfile = profile;
        _nameController.text = profile?.displayName ?? '';
        _selectedDept = profile?.department ?? 'Science';
        _isLoading = false;
      });

      if (profile != null) {
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error loading profile: $e', isError: true);
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
        backgroundColor: isError ? Colors.red.shade700 : _accentGreen,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    final trimmedName = _nameController.text.trim();

    if (trimmedName.isEmpty) {
      _showSnackBar('Name cannot be empty', isError: true);
      return;
    }
    if (trimmedName.length < 3) {
      _showSnackBar('Name must be at least 3 characters', isError: true);
      return;
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmedName)) {
      _showSnackBar('Name can only contain letters and spaces', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await _userService.updateProfile(
        displayName: trimmedName,
        department: _selectedDept,
      );

      if (!mounted) return;

      if (success) {
        await _loadUserProfile();
        if (!mounted) return;
        setState(() => _isEditing = false);
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

  Future<bool> _hasInternetOrShowError() async {
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!mounted) return false;

    if (!hasInternet) {
      _showSnackBar('Check your internet connection and try again',
          isError: true);
      return false;
    }

    return true;
  }

  void _showLoadingDialog({
    required Color indicatorColor,
    String? message,
  }) {
    _isProgressDialogVisible = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);

        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.dialogTheme.backgroundColor ?? theme.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: indicatorColor,
                    strokeWidth: 2.5,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (!_isProgressDialogVisible || !mounted) return;
    _isProgressDialogVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<bool?> _showConfirmationDialog({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final onSurface = theme.colorScheme.onSurface;
        final subduedText = onSurface.withValues(alpha: 0.6);
        final cancelBg = theme.brightness == Brightness.dark
            ? Colors.white12
            : Colors.grey.shade100;
        final cancelText = theme.brightness == Brightness.dark
            ? Colors.white70
            : Colors.grey.shade600;

        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: subduedText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogContext, false),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: cancelBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: cancelText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              confirmText,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showDeleteTypingDialog() {
    _deleteConfirmController.clear();

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final textColor = theme.colorScheme.onSurface;
        final subtextColor = textColor.withValues(alpha: 0.6);

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isValid = _deleteConfirmController.text.trim() == 'DELETE';

            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you absolutely sure?',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Type DELETE below to permanently delete your account.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: subtextColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _deleteConfirmController,
                      onChanged: (_) => setDialogState(() {}),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type DELETE here',
                        hintStyle: GoogleFonts.poppins(fontSize: 13),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.red.shade400,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: isValid
                          ? () => Navigator.pop(dialogContext, true)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isValid
                              ? Colors.red.shade600
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Permanently Delete Account',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color:
                                  isValid ? Colors.white : Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext, false),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: subtextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await _showConfirmationDialog(
      icon: Icons.logout_rounded,
      accentColor: Colors.red.shade600,
      title: 'Log Out?',
      message: 'Are you sure you want to log out of your account?',
      confirmText: 'Log Out',
    );

    if (!mounted || confirmed != true) return;
    await _performLogout();
  }

  Future<void> _performLogout() async {
    final hasInternet = await _hasInternetOrShowError();
    if (!hasInternet || !mounted) return;

    _showLoadingDialog(indicatorColor: _accentGreen);

    try {
      await NotificationService().onUserLogout();
      if (!mounted) return;
      await context.read<AuthService>().signOut();

      if (!mounted) return;
      _hideLoadingDialog();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      _hideLoadingDialog();
      _showSnackBar('Check your internet connection and try again',
          isError: true);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final firstConfirm = await _showConfirmationDialog(
      icon: Icons.delete_forever_rounded,
      accentColor: Colors.red.shade600,
      title: 'Delete Account?',
      message:
          'This will permanently delete your account and all associated data '
          'including quiz progress, streaks, bookmarks, and purchased '
          'subjects.\n\nThis action cannot be undone.',
      confirmText: 'Delete',
    );

    if (!mounted || firstConfirm != true) return;

    final secondConfirm = await _showDeleteTypingDialog();
    if (!mounted || secondConfirm != true) return;

    await _performDeleteAccount();
  }

  Future<void> _performDeleteAccount() async {
    final hasInternet = await _hasInternetOrShowError();
    if (!hasInternet || !mounted) return;

    setState(() => _isDeletingAccount = true);
    _showLoadingDialog(
      indicatorColor: Colors.red.shade600,
      message: 'Deleting account...',
    );

    try {
      await NotificationService().onUserLogout();
      if (!mounted) return;
      await context.read<AuthService>().deleteAccount();

      if (!mounted) return;
      _hideLoadingDialog();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _hideLoadingDialog();
      _showSnackBar(_formatDeleteAccountError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  String _formatDeleteAccountError(Object error) {
    final rawMessage = error.toString().replaceFirst('Exception: ', '').trim();
    if (rawMessage.isEmpty) {
      return 'Failed to delete account. Please try again.';
    }
    return rawMessage;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final subtextColor = textColor.withValues(alpha: 0.65);
    final dividerColor = theme.dividerColor;
    final shadowColor = theme.shadowColor;
    final fieldFillColor = theme.inputDecorationTheme.fillColor ?? cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
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
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: _cancelEditing,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
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
                      ),
                    GestureDetector(
                      onTap: () => context.read<ThemeProvider>().toggleTheme(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 56,
                        height: 30,
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? const Color(0xFF1A2E1F)
                              : Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: themeProvider.isDarkMode
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    themeProvider.isDarkMode
                                        ? Icons.nightlight_round
                                        : Icons.wb_sunny_rounded,
                                    size: 13,
                                    color: themeProvider.isDarkMode
                                        ? const Color(0xFF1A2E1F)
                                        : const Color(0xFFFFB300),
                                  ),
                                ),
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
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: _accentGreen,
                      strokeWidth: 2.5,
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor.withValues(
                                      alpha: isDark ? 0.35 : 0.12,
                                    ),
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
                                      color: _accentGreen.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _accentGreen,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.school_rounded,
                                      size: 32,
                                      color: _accentGreen,
                                    ),
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
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _userProfile?.email ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: subtextColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _accentGreen.withValues(
                                              alpha: 0.1,
                                            ),
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
                            const SizedBox(height: 20),
                            Text(
                              'EDIT PROFILE',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _accentGreen,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor.withValues(
                                      alpha: isDark ? 0.35 : 0.12,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: textColor,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'User Name',
                                  labelStyle: GoogleFonts.poppins(
                                    color: subtextColor,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: _accentGreen,
                                    size: 20,
                                  ),
                                  fillColor: fieldFillColor,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                onChanged: (_) {
                                  if (!_isEditing) {
                                    setState(() => _isEditing = true);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'DEPARTMENT',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _accentGreen,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._departments.map((dept) {
                              final isSelected = _selectedDept == dept['name'];
                              final color = dept['color'] as Color;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDept = dept['name'] as String;
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
                                        : cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? color : dividerColor,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isSelected ? color : shadowColor)
                                            .withValues(
                                          alpha: isSelected
                                              ? 0.15
                                              : (isDark ? 0.28 : 0.08),
                                        ),
                                        blurRadius: isSelected ? 12 : 8,
                                        offset: Offset(
                                          0,
                                          isSelected ? 4 : 2,
                                        ),
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
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          dept['name'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color:
                                                isSelected ? color : textColor,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: color,
                                          size: 22,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 24),
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
                                        color: _accentGreen.withValues(
                                          alpha: 0.35,
                                        ),
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
                            GestureDetector(
                              onTap: _confirmLogout,
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: shadowColor.withValues(
                                        alpha: isDark ? 0.25 : 0.08,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.logout_rounded,
                                      color: Colors.red.shade600,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
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
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _isDeletingAccount
                                  ? null
                                  : _confirmDeleteAccount,
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.red.shade900.withValues(
                                          alpha: 0.25,
                                        )
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.delete_forever_rounded,
                                      color: Colors.red.shade700,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete Account',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'Deleting your account is permanent and cannot '
                                'be undone.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: subtextColor,
                                  height: 1.5,
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
