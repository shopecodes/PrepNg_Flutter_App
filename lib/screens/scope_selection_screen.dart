// lib/screens/scope_selection_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:prep_ng/screens/settings_screen.dart';
import '../services/user_service.dart';
import 'subject_list_screen.dart';
import 'progress/progress_history_screen.dart';

class ScopeSelectionScreen extends StatefulWidget {
  const ScopeSelectionScreen({super.key});

  @override
  State<ScopeSelectionScreen> createState() => _ScopeSelectionScreenState();
}

class _ScopeSelectionScreenState extends State<ScopeSelectionScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isOffline = false;
  String _userName = '';
  final _userService = UserService();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color palette
  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  // Exam card configs — icon + gradient per exam type
  final Map<String, Map<String, dynamic>> _scopeConfig = {
    'JAMB': {
      'icon': Icons.school_rounded,
      'gradient': [Color(0xFF4CAF7D), Color(0xFF2E8B57)],
      'tag': 'UTME',
      'description': 'Unified Tertiary Matriculation Exam',
    },
    'WAEC': {
      'icon': Icons.menu_book_rounded,
      'gradient': [Color(0xFF3A86FF), Color(0xFF1A5CCC)],
      'tag': 'SSCE',
      'description': 'West African Senior School Certificate',
    },
  };

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _preFetchScopes();
    _loadUserName();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (mounted) {
        setState(() {
          _isOffline = result.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _loadUserName() async {
    try {
      final userProfile = await _userService.getUserProfile();
      if (userProfile != null && userProfile.displayName != null) {
        final firstName = userProfile.displayName!.split(' ').first;
        if (mounted) setState(() => _userName = firstName);
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
    }
  }

  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOffline = result.contains(ConnectivityResult.none));
    }
  }

  Future<void> _preFetchScopes() async {
    try {
      await FirebaseFirestore.instance
          .collection('scope')
          .get(const GetOptions(source: Source.serverAndCache));
    } catch (e) {
      debugPrint('Cache warm-up failed: $e');
    }
  }

  void _onTabTapped(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ProgressHistoryScreen()),
      );
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName.isEmpty
                                  ? 'Good day! 👋'
                                  : 'Hi, $_userName! 👋',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _darkGreen,
                              ),
                            ),
                            Text(
                              'Which exam are you prepping for?',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Offline badge
                      if (_isOffline)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.orange.shade200, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_off_rounded,
                                  size: 14, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Offline',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Settings button
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (context) => const SettingsScreen()))
                              .then((_) => _loadUserName());
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.settings_rounded,
                              size: 20, color: _darkGreen),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── "Choose Your Exam" label ──────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'SELECT EXAM',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _accentGreen,
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Exam Cards + Illustration ────────────────────────────────────────
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('scope')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                              color: _accentGreen, strokeWidth: 2.5),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error loading exams!',
                              style: GoogleFonts.poppins()),
                        );
                      }
                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text('No exam types found.',
                              style: GoogleFonts.poppins()),
                        );
                      }

                      final scopes = snapshot.data!.docs;

                      return Column(
                        children: [
                          // Exam cards list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 4),
                              itemCount: scopes.length,
                              itemBuilder: (context, index) {
                                final scope = scopes[index];
                                final scopeId = scope.id;
                                final name = scope['name'] as String;
                                final config = _scopeConfig[name] ??
                                    {
                                      'icon': Icons.school_rounded,
                                      'gradient': [_accentGreen, _darkGreen],
                                      'tag': '',
                                      'description': '',
                                    };

                                final gradientColors =
                                    config['gradient'] as List<Color>;

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => SubjectListScreen(
                                          scopeId: scopeId,
                                          scopeName: name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    height: 160,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradientColors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: gradientColors[0].withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // Decorative circle top-right
                                        Positioned(
                                          top: -20,
                                          right: -20,
                                          child: Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withValues(alpha: 0.08),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: -30,
                                          right: 40,
                                          child: Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withValues(alpha: 0.06),
                                            ),
                                          ),
                                        ),

                                        // Content
                                        Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                    ),
                                                    child: Icon(
                                                      config['icon'] as IconData,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    name,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.25),
                                                      borderRadius:
                                                          BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      config['tag'] as String,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      config['description'] as String,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        color: Colors.white.withValues(alpha: 0.8),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(10),
                                                    ),
                                                    child: const Icon(
                                                      Icons.arrow_forward_rounded,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          // Illustration at bottom with blur effect
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 0.3, sigmaY: 0.3),
                              child: Opacity(
                                opacity: 0.6,
                                child: Image.asset(
                                  'assets/images/Student stress-bro.png',
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ── Bottom Nav ────────────────────────────────────────────────
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedItemColor: _accentGreen,
              unselectedItemColor: Colors.grey.shade400,
              showSelectedLabels: true,
              showUnselectedLabels: false,
              selectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 12),
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.history_rounded), label: 'History'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}