// lib/screens/streak/streak_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/streak_service.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen>
    with SingleTickerProviderStateMixin {

  final StreakService _streakService = StreakService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  StreakData? _streakData;
  bool _isLoading = true;

  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);
  static const Color _orange = Color(0xFFE89B4A);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );

    _loadStreak();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadStreak() async {
    setState(() => _isLoading = true);
    final data = await _streakService.getStreakData();
    if (mounted) {
      setState(() {
        _streakData = data;
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  // ── Last 10 weeks of days (70 days) for the heatmap ───────────
  List<DateTime> _getLast70Days() {
    final today = DateTime.now();
    return List.generate(70, (i) {
      return DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 69 - i));
    });
  }

  bool _isActiveDay(DateTime day, List<DateTime> activeDays) {
    return activeDays.any((d) =>
        d.year == day.year && d.month == day.month && d.day == day.day);
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  String _getStreakMessage(int streak) {
    if (streak == 0) return 'Start your streak today!';
    if (streak < 3) return 'You\'re just getting started 💪';
    if (streak < 7) return 'Building momentum 🔥';
    if (streak < 14) return 'On fire! Keep it up 🚀';
    if (streak < 30) return 'Unstoppable! 🏆';
    return 'Legendary streak! 👑';
  }

  Color _getStreakColor(int streak) {
    if (streak == 0) return Colors.grey.shade400;
    if (streak < 7) return _orange;
    return _accentGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: _accentGreen, strokeWidth: 3))
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    final streak = _streakData?.currentStreak ?? 0;
    final streakColor = _getStreakColor(streak);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: streak >= 7
              ? [_accentGreen, const Color(0xFF2E8B57)]
              : streak > 0
                  ? [_orange, const Color(0xFFD4782A)]
                  : [Colors.grey.shade500, Colors.grey.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: streakColor.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_fire_department_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Study Streak',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Big streak number
              ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_streakData?.currentStreak ?? 0}',
                          style: GoogleFonts.poppins(
                            fontSize: 80,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 6),
                          child: Text(
                            'day${(_streakData?.currentStreak ?? 0) == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _getStreakMessage(_streakData?.currentStreak ?? 0),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────
  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: _orange,
                    label: 'Current Streak',
                    value: '${_streakData?.currentStreak ?? 0}',
                    unit: 'days',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.emoji_events_rounded,
                    iconColor: const Color(0xFFFFD700),
                    label: 'Best Streak',
                    value: '${_streakData?.bestStreak ?? 0}',
                    unit: 'days',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.calendar_today_rounded,
                    iconColor: _accentGreen,
                    label: 'Total Days',
                    value: '${_streakData?.activeDays.length ?? 0}',
                    unit: 'active',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Activity heatmap
            _buildHeatmap(),

            const SizedBox(height: 28),

            // Milestones
            _buildMilestones(),
          ],
        ),
      ),
    );
  }

  // ── Heatmap ────────────────────────────────────────────────────
  Widget _buildHeatmap() {
    final days = _getLast70Days();
    final activeDays = _streakData?.activeDays ?? [];
    final weekLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Group into columns of 7 (each column = one week)
    final weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, color: _accentGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Activity — Last 10 Weeks',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Day labels (Mon–Sun)
          Row(
            children: [
              const SizedBox(width: 4),
              ...weekLabels.map((label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 6),

          // Grid — rows = weeks (columns), cells = days
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: weeks.map((week) {
              return Expanded(
                child: Column(
                  children: week.map((day) {
                    final active = _isActiveDay(day, activeDays);
                    final today = _isToday(day);

                    return Container(
                      margin: const EdgeInsets.all(2.5),
                      width: double.infinity,
                      height: 28,
                      decoration: BoxDecoration(
                        color: today
                            ? _accentGreen
                            : active
                                ? _accentGreen.withValues(alpha: 0.75)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: today
                            ? Border.all(
                                color: _darkGreen.withValues(alpha: 0.3),
                                width: 1.5)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          // Legend
          Row(
            children: [
              const Spacer(),
              _legendDot(Colors.grey.shade100, 'No activity'),
              const SizedBox(width: 12),
              _legendDot(_accentGreen.withValues(alpha: 0.75), 'Studied'),
              const SizedBox(width: 12),
              _legendDot(_accentGreen, 'Today'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // ── Milestones ─────────────────────────────────────────────────
  Widget _buildMilestones() {
    final current = _streakData?.currentStreak ?? 0;
    final best = _streakData?.bestStreak ?? 0;

    final milestones = [
      _Milestone(days: 3, icon: '🌱', label: 'Seedling'),
      _Milestone(days: 7, icon: '🔥', label: 'On Fire'),
      _Milestone(days: 14, icon: '⚡', label: 'Electric'),
      _Milestone(days: 30, icon: '🏆', label: 'Champion'),
      _Milestone(days: 60, icon: '👑', label: 'Legendary'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded,
                  color: _accentGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Milestones',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...milestones.map((m) {
            final achieved = best >= m.days;
            final inProgress = current > 0 && current < m.days && best < m.days;
            final progressValue =
                inProgress ? (current / m.days).clamp(0.0, 1.0) : 1.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: achieved
                          ? _accentGreen.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(m.icon,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              m.label,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: achieved ? _darkGreen : Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              achieved
                                  ? '✓ Achieved'
                                  : '${m.days} days',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: achieved
                                    ? _accentGreen
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: achieved ? 1.0 : progressValue,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              achieved ? _accentGreen : _orange,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  static const Color _darkGreen = Color(0xFF1A2E1F);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _darkGreen,
              height: 1,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Milestone {
  final int days;
  final String icon;
  final String label;
  const _Milestone(
      {required this.days, required this.icon, required this.label});
}