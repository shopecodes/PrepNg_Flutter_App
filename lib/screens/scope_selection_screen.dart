// lib/screens/scope_selection_screen.dart

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
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isOffline = false;
  String _userName = '';
  final _userService = UserService();

  // ── Single animation controller for the whole page ────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color _accentGreen = Color(0xFF4CAF7D);

  final Map<String, Map<String, dynamic>> _scopeConfig = {
    'JAMB': {
      'icon': Icons.school_rounded,
      'gradient': [Color(0xFF4CAF7D), Color(0xFF2E9E65)],
      'tag': 'UTME',
      'description': 'Unified Tertiary Matriculation Exam',
      'watermarkIcon': Icons.school_rounded,
    },
    'WAEC': {
      'icon': Icons.menu_book_rounded,
      'gradient': [Color(0xFF3A86FF), Color(0xFF1A5CCC)],
      'tag': 'SSCE',
      'description': 'West African Senior School Certificate',
      'watermarkIcon': Icons.menu_book_rounded,
    },
  };

  final List<Map<String, dynamic>> _quickActions = [
    {'label': 'QOTD',   'icon': Icons.lightbulb_rounded,            'color': Color(0xFFFFC107), 'bg': Color(0xFFFFF8E1), 'bgDark': Color(0xFF332800)},
    {'label': 'Saved',  'icon': Icons.bookmark_rounded,              'color': Color(0xFF3A86FF), 'bg': Color(0xFFE8F0FF), 'bgDark': Color(0xFF0A1A33)},
    {'label': 'Streak', 'icon': Icons.local_fire_department_rounded, 'color': Color(0xFFFF6B35), 'bg': Color(0xFFFFF0EB), 'bgDark': Color(0xFF331500)},
    {'label': 'Rank',   'icon': Icons.emoji_events_rounded,          'color': Color(0xFF9B59B6), 'bg': Color(0xFFF5EEFB), 'bgDark': Color(0xFF1E0A2E)},
    {'label': 'Mock',   'icon': Icons.assignment_rounded,            'color': Color(0xFF4CAF7D), 'bg': Color(0xFFE8F5EE), 'bgDark': Color(0xFF0A2218)},
  ];

  static const List<String> _tips = [
    'Consistency beats intensity. 30 mins daily > 3 hrs once a week.',
    'Review your wrong answers — they\'re your best teachers.',
    'Start with your strongest subject to build momentum.',
    'Sleep well before exam day. Your brain consolidates at night.',
    'Break big topics into small chunks. One at a time.',
    'Mock exams train your timing. Speed comes from practice.',
    'Read every question twice before answering — don\'t rush.',
    'Use the bookmark feature to save tricky questions and revisit them.',
    'Track your streak daily — even 10 questions a day adds up fast.',
    'Focus on understanding, not memorising. Concepts repeat across topics.',
  ];

  String get _dailyTip {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    return _tips[dayOfYear % _tips.length];
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _greetingEmoji {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  void _onQuickActionTap(String label) {
    switch (label) {
      case 'QOTD':
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QuestionOfTheDayScreen()));
        break;
      case 'Saved':
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BookmarksScreen()));
        break;
      case 'Streak':
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StreakScreen()));
        break;
      case 'Rank':
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
        break;
      case 'Mock':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const MockSubjectSelectionScreen()));
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
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      if (mounted) {
        setState(
            () => _isOffline = result.contains(ConnectivityResult.none));
      }
    });
  }

  Future<void> _loadUserName() async {
    try {
      final userProfile = await _userService.getUserProfile();
      if (userProfile != null && userProfile.displayName != null) {
        final firstName = userProfile.displayName!.split(' ').first;
        if (mounted) {
          setState(() {
            _userName = firstName;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
    }
  }

  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(
          () => _isOffline = result.contains(ConnectivityResult.none));
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
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const ProgressHistoryScreen()));
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final subtextColor = textColor.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: bgColor,
      // ── Custom bottom nav ──────────────────────────────────────
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        isDark: isDark,
        cardColor: cardColor,
        onTap: _onTabTapped,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.45, 1.0],
            colors: isDark
                ? [
                    const Color(0xFF1A2E22),
                    const Color(0xFF121817),
                    const Color(0xFF121817),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFFE0F2E9),
                    const Color(0xFFFFFFFF),
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

                  // ── Top Bar ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName.isEmpty
                                    ? '$_greeting $_greetingEmoji'
                                    : '$_greeting,',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: subtextColor,
                                ),
                              ),
                              if (_userName.isNotEmpty)
                                Text(
                                  '$_userName! $_greetingEmoji',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    height: 1.1,
                                  ),
                                ),
                              if (_userName.isEmpty)
                                Text(
                                  'Which exam are you prepping for?',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: subtextColor),
                                ),
                              if (_userName.isNotEmpty)
                                Text(
                                  'Which exam are you prepping for?',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: subtextColor),
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

                        // ── settings button ──────────────
                        GestureDetector(
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (context) =>
                                      const SettingsScreen()))
                              .then((_) => _loadUserName()),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor.withValues(
                                      alpha: isDark ? 0.3 : 0.16),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(Icons.settings_rounded,
                                size: 20, color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Quick Actions ─────────────────────────────────
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _quickActions.length,
                      itemBuilder: (context, index) {
                        final action = _quickActions[index];
                        final bg = isDark
                            ? action['bgDark'] as Color
                            : action['bg'] as Color;
                        return GestureDetector(
                          onTap: () => _onQuickActionTap(
                              action['label'] as String),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color: (action['color'] as Color)
                                        .withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(action['icon'] as IconData,
                                    color: action['color'] as Color,
                                    size: 22),
                                const SizedBox(height: 4),
                                Text(action['label'] as String,
                                    style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: action['color'] as Color)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Tip of the day ────────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A2E22)
                            : const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                _accentGreen.withValues(alpha: 0.25),
                            width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color:
                                  _accentGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.lightbulb_rounded,
                                color: _accentGreen, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _dailyTip,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF2E6B4A),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ── SELECT EXAM divider header ────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: _accentGreen.withValues(alpha: 0.30),
                                thickness: 1)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('SELECT EXAM',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _accentGreen,
                                  letterSpacing: 2)),
                        ),
                        Expanded(
                            child: Divider(
                                color: _accentGreen.withValues(alpha: 0.30),
                                thickness: 1)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Exam Cards ────────────────────────────────────
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
                                  color: _accentGreen,
                                  strokeWidth: 2.5));
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error loading exams!',
                                  style: GoogleFonts.poppins(
                                      color: textColor)));
                        }
                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty) {
                          return Center(
                              child: Text('No exam types found.',
                                  style: GoogleFonts.poppins(
                                      color: textColor)));
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
                                  final name =
                                      scope['name'] as String;
                                  final config =
                                      _scopeConfig[name] ?? {
                                    'icon': Icons.school_rounded,
                                    'gradient': [
                                      _accentGreen,
                                      const Color(0xFF1A2E1F)
                                    ],
                                    'tag': '',
                                    'description': '',
                                    'watermarkIcon':
                                        Icons.school_rounded,
                                  };
                                  final gradientColors =
                                      config['gradient']
                                          as List<Color>;

                                  return GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SubjectListScreen(
                                                scopeId: scopeId,
                                                scopeName: name),
                                      ),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 16),
                                      height: 114,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: gradientColors,
                                            begin: Alignment.topLeft,
                                            end:
                                                Alignment.bottomRight),
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                              color: gradientColors[0]
                                                  .withValues(
                                                      alpha: 0.38),
                                              blurRadius: 22,
                                              offset:
                                                  const Offset(0, 10))
                                        ],
                                      ),
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          // Decorative circles
                                          Positioned(
                                            top: -20, right: -20,
                                            child: Container(
                                                width: 130, height: 130,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white.withValues(alpha: 0.08)))),
                                          Positioned(
                                            bottom: -30, right: 50,
                                            child: Container(
                                                width: 110, height: 110,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white.withValues(alpha: 0.05)))),
                                          // Watermark icon
                                          Positioned(
                                            right: -10, bottom: -10,
                                            child: Icon(
                                              config['watermarkIcon'] as IconData,
                                              size: 110,
                                              color: Colors.white.withValues(alpha: 0.07),
                                            ),
                                          ),
                                          // Content
                                          Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.22),
                                                        borderRadius: BorderRadius.circular(12)),
                                                    child: Icon(config['icon'] as IconData,
                                                        color: Colors.white, size: 20),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(name,
                                                      style: GoogleFonts.poppins(
                                                          fontSize: 22,
                                                          fontWeight: FontWeight.w800,
                                                          color: Colors.white)),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                                      child: Text(config['description'] as String,
                                                          style: GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              color: Colors.white.withValues(alpha: 0.82))),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.all(9),
                                                      decoration: BoxDecoration(
                                                          color: Colors.white.withValues(alpha: 0.22),
                                                          borderRadius: BorderRadius.circular(11)),
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

                            // Decorative illustration
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                              child: Opacity(
                                opacity: 0.85,
                                child: Image.asset(
                                  'assets/images/Education-rafiki.png',
                                  height: 180,
                                  fit: BoxFit.contain,
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
      ),
    );
  }
}

// ── Custom bottom navigation bar ──────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final Color cardColor;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.isDark,
    required this.cardColor,
    required this.onTap,
  });

  static const Color _accentGreen = Color(0xFF4CAF7D);

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_rounded,    label: 'Home'),
    _NavItem(icon: Icons.history_rounded, label: 'History'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, right: 40, bottom: 28),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final isSelected = index == currentIndex;
            return GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _accentGreen.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                              color: isSelected
                                  ? _accentGreen
                                  : (isDark
                              ? Colors.white54
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45)),
                      size: 22,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _accentGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
