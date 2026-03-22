// lib/screens/leaderboard/leaderboard_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/leaderboard_service.dart';
import '../../services/connectivity_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {

  final LeaderboardService _leaderboardService = LeaderboardService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _myRank;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isOffline = false;

  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isOffline = false;
    });

    // Check connectivity first before showing cached data banner if offline
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (mounted) setState(() => _isOffline = !hasInternet);

    try {
      final results = await Future.wait([
        _leaderboardService.getWeeklyLeaderboard(),
        _leaderboardService.getMyRank(),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Leaderboard load timed out');
        },
      );

      if (mounted) {
        setState(() {
          _entries = results[0] as List<LeaderboardEntry>;
          _myRank = results[1] as LeaderboardEntry?;
          _isLoading = false;
        });
        _fadeController.forward(from: 0);
      }
    } on TimeoutException {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
      connectivityScaffoldKey.currentState?.showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Connection timed out. Please check your internet.',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A2E1F),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
      connectivityScaffoldKey.currentState?.showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Failed to load leaderboard. Please try again.',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFB0B0B0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade300;
  }

  String _departmentEmoji(String dept) {
    switch (dept.toLowerCase()) {
      case 'science': return '🔬';
      case 'arts': return '🎨';
      case 'commercial': return '💼';
      default: return '📚';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildHeader(),
          if (_isOffline && !_isLoading && !_hasError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Showing cached data — connect to see latest rankings',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(
                    color: _accentGreen, strokeWidth: 3))
                : _hasError
                    ? _buildError()
                    : _entries.isEmpty
                        ? _buildEmpty()
                        : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
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
            color: _accentGreen.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.leaderboard_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leaderboard',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _leaderboardService.currentWeekLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),

              if (_myRank != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '#${_myRank!.rank}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your rank this week',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            Text(
                              '${_myRank!.totalScore} pts · ${_myRank!.quizzesTaken} quiz${_myRank!.quizzesTaken == 1 ? '' : 'zes'}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _departmentEmoji(_myRank!.department),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Error State ────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 52, color: _accentGreen.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text('No connection',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _darkGreen)),
            const SizedBox(height: 10),
            Text(
              'Check your internet and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: _accentGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Retry',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.leaderboard_rounded,
                  size: 42, color: _accentGreen.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            Text(
              'No entries yet',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _darkGreen),
            ),
            const SizedBox(height: 10),
            Text(
              'Complete quizzes this week to\nappear on the leaderboard.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────────
  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        color: _accentGreen,
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: _entries.length,
          itemBuilder: (context, index) {
            final entry = _entries[index];
            final isMe = entry.uid == _currentUid;
            final isTop3 = entry.rank <= 3;

            if (isTop3) {
              return _TopThreeCard(
                entry: entry,
                isMe: isMe,
                rankColor: _rankColor(entry.rank),
                departmentEmoji: _departmentEmoji(entry.department),
              );
            }

            return _LeaderboardRow(
              entry: entry,
              isMe: isMe,
              departmentEmoji: _departmentEmoji(entry.department),
            );
          },
        ),
      ),
    );
  }
}

// ── Top 3 Card ─────────────────────────────────────────────────────────────────
class _TopThreeCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final Color rankColor;
  final String departmentEmoji;

  const _TopThreeCard({
    required this.entry,
    required this.isMe,
    required this.rankColor,
    required this.departmentEmoji,
  });

  static const Color _darkGreen = Color(0xFF1A2E1F);
  static const Color _accentGreen = Color(0xFF4CAF7D);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isMe
            ? Border.all(color: _accentGreen, width: 2)
            : Border.all(color: rankColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: rankColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: rankColor, width: 2),
            ),
            child: Center(
              child: Icon(Icons.emoji_events_rounded,
                  color: rankColor, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _darkGreen,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'You',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _accentGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$departmentEmoji ${entry.department}  ·  ${entry.quizzesTaken} quiz${entry.quizzesTaken == 1 ? '' : 'zes'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalScore}',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _darkGreen,
                ),
              ),
              Text(
                'pts',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Regular Row ────────────────────────────────────────────────────────────────
class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final String departmentEmoji;

  const _LeaderboardRow({
    required this.entry,
    required this.isMe,
    required this.departmentEmoji,
  });

  static const Color _darkGreen = Color(0xFF1A2E1F);
  static const Color _accentGreen = Color(0xFF4CAF7D);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe
            ? _accentGreen.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? _accentGreen.withValues(alpha: 0.3)
              : Colors.grey.shade100,
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isMe
                  ? _accentGreen.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.displayName.isNotEmpty
                    ? entry.displayName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isMe ? _accentGreen : Colors.grey.shade500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _darkGreen,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _accentGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'You',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _accentGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '$departmentEmoji  ${entry.quizzesTaken} quiz${entry.quizzesTaken == 1 ? '' : 'zes'}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.totalScore} pts',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isMe ? _accentGreen : _darkGreen,
            ),
          ),
        ],
      ),
    );
  }
}