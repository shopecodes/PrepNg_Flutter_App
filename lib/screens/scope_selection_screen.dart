// lib/screens/scope_selection_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:prep_ng/screens/mock_subject_selection_screen.dart';
import 'package:prep_ng/screens/settings_screen.dart';
import '../services/user_service.dart';
import 'subject_list_screen.dart';
import 'progress/progress_history_screen.dart';
import 'bookmarks_screen.dart';
import 'leaderboard_screen.dart';
import 'question_of_the_day_screen.dart';
import 'streaks_screen.dart';

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

  // ── Color palette (Plandra-style, green version) ──────────────
  static const Color _bgColor      = Color(0xFFF0F7F2);
  static const Color _accentGreen  = Color(0xFF4CAF7D);
  static const Color _darkGreen    = Color(0xFF1A2E1F);
// tinted chip/badge bg

  final Map<String, Map<String, dynamic>> _scopeConfig = {
    'JAMB': {
      'icon': Icons.school_rounded,
      'gradient': [Color(0xFF4CAF7D), Color.fromARGB(255, 58, 188, 114)],
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

  final List<Map<String, dynamic>> _quickActions = [
    {'label': 'QOTD',   'icon': Icons.lightbulb_rounded,             'color': Color(0xFFFFC107), 'bg': Color(0xFFFFF8E1)},
    {'label': 'Saved',  'icon': Icons.bookmark_rounded,               'color': Color(0xFF3A86FF), 'bg': Color(0xFFE8F0FF)},
    {'label': 'Streak', 'icon': Icons.local_fire_department_rounded,  'color': Color(0xFFFF6B35), 'bg': Color(0xFFFFF0EB)},
    {'label': 'Rank',   'icon': Icons.emoji_events_rounded,           'color': Color(0xFF9B59B6), 'bg': Color(0xFFF5EEFB)},
    {'label': 'Mock',   'icon': Icons.assignment_rounded,             'color': Color(0xFF4CAF7D), 'bg': Color(0xFFE8F5EE)},
  ];

  void _onQuickActionTap(String label) {
    switch (label) {
      case 'QOTD':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const QuestionOfTheDayScreen()));
        break;
      case 'Saved':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const BookmarksScreen()));
        break;
      case 'Streak':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const StreakScreen()));
        break;
      case 'Rank':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const LeaderboardScreen()));
        break;
      case 'Mock':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const MockSubjectSelectionScreen(),
        ));
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _preFetchScopes();
    _loadUserName();

    _animController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (mounted) {
        setState(() => _isOffline = result.contains(ConnectivityResult.none));
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
          MaterialPageRoute(builder: (context) => const ProgressHistoryScreen()));
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.45, 1.0],
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFE0F2E9),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Bar ───────────────────────────────────────────
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
                                  color: _darkGreen),
                            ),
                            Text('Which exam are you prepping for?',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
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
                          child: Row(children: [
                            Icon(Icons.cloud_off_rounded,
                                size: 14, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Text('Offline',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700)),
                          ]),
                        ),
                      GestureDetector(
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (context) => const SettingsScreen()))
                            .then((_) => _loadUserName()),
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
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Icon(Icons.settings_rounded,
                              size: 20, color: _darkGreen),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Quick Actions ─────────────────────────────────────
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _quickActions.length,
                    itemBuilder: (context, index) {
                      final action = _quickActions[index];
                      return GestureDetector(
                        onTap: () =>
                            _onQuickActionTap(action['label'] as String),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: action['bg'] as Color,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: (action['color'] as Color)
                                      .withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(action['icon'] as IconData,
                                  color: action['color'] as Color, size: 20),
                              const SizedBox(height: 4),
                              Text(action['label'] as String,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: action['color'] as Color)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('SELECT EXAM',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _accentGreen,
                          letterSpacing: 2)),
                ),

                const SizedBox(height: 12),

                // ── Exam Cards ────────────────────────────────────────
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('scope')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                            child: CircularProgressIndicator(
                                color: _accentGreen, strokeWidth: 2.5));
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Error loading exams!',
                                style: GoogleFonts.poppins()));
                      }
                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return Center(
                            child: Text('No exam types found.',
                                style: GoogleFonts.poppins()));
                      }

                      final scopes = snapshot.data!.docs;

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 2),
                              itemCount: scopes.length,
                              itemBuilder: (context, index) {
                                final scope = scopes[index];
                                final scopeId = scope.id;
                                final name = scope['name'] as String;
                                final config = _scopeConfig[name] ?? {
                                  'icon': Icons.school_rounded,
                                  'gradient': [_accentGreen, _darkGreen],
                                  'tag': '',
                                  'description': '',
                                };
                                final gradientColors =
                                    config['gradient'] as List<Color>;

                                return GestureDetector(
                                  onTap: () =>
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                    builder: (context) => SubjectListScreen(
                                        scopeId: scopeId,
                                        scopeName: name),
                                  )),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    height: 120,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          colors: gradientColors,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                            color: gradientColors[0].withValues(alpha: 0.35),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10))
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                            top: -20,
                                            right: -20,
                                            child: Container(
                                                width: 120,
                                                height: 120,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white.withValues(alpha: 0.08)))),
                                        Positioned(
                                            bottom: -30,
                                            right: 40,
                                            child: Container(
                                                width: 100,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white.withValues(alpha: 0.06)))),
                                        Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(12)),
                                                  child: Icon(config['icon'] as IconData,
                                                      color: Colors.white, size: 20),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(name,
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white)),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.25),
                                                      borderRadius: BorderRadius.circular(20)),
                                                  child: Text(config['tag'] as String,
                                                      style: GoogleFonts.poppins(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                          letterSpacing: 0.5)),
                                                ),
                                              ]),
                                              const Spacer(),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                      child: Text(
                                                          config['description'] as String,
                                                          style: GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              color: Colors.white.withValues(alpha: 0.8)))),
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(10)),
                                                    child: const Icon(Icons.arrow_forward_rounded,
                                                        color: Colors.white, size: 18),
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
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            child: ImageFiltered(
                              imageFilter:
                                  ImageFilter.blur(sigmaX: 0.3, sigmaY: 0.3),
                              child: Opacity(
                                  opacity: 0.6,
                                  child: Image.asset(
                                      'assets/images/Student stress-bro.png',
                                      height: 175,
                                      fit: BoxFit.contain)),
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
      ),
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
                  offset: const Offset(0, 10))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedItemColor: const Color.fromARGB(255, 8, 131, 69),
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