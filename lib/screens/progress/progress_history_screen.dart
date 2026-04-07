// lib/screens/progress/progress_history_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/progress_service.dart';

class ProgressHistoryScreen extends StatefulWidget {
  const ProgressHistoryScreen({super.key});

  @override
  State<ProgressHistoryScreen> createState() => _ProgressHistoryScreenState();
}

class _ProgressHistoryScreenState extends State<ProgressHistoryScreen>
    with TickerProviderStateMixin {
  final ProgressService _progressService = ProgressService();

  late TabController _tabController;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Color _scoreColor(double percent) {
    if (percent >= 70) return _accentGreen;
    if (percent >= 50) return const Color(0xFFE89B4A);
    return Colors.red.shade400;
  }

  String _scoreLabel(double percent) {
    if (percent >= 70) return 'Great';
    if (percent >= 50) return 'Fair';
    return 'Retry';
  }

  Future<void> _showClearDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
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
                child: Icon(Icons.delete_sweep_rounded,
                    color: Colors.red.shade600, size: 26),
              ),
              const SizedBox(height: 16),
              Text('Clear All History?',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkGreen)),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete all your quiz records. This cannot be undone.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade500, height: 1.5),
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
                      onTap: () => Navigator.pop(dialogContext, true),
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
                          child: Text('Delete All',
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

    if (confirm != true || !mounted) return;

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

    try {
      final bool hadData = await _progressService.clearUserHistory();
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hadData ? 'History cleared' : 'No history to clear',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: hadData ? _accentGreen : Colors.grey.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear history: $e',
                style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Progress',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Your quiz & mock exam history',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color:
                                      Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _showClearDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.delete_sweep_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text('Clear',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: _accentGreen,
                        unselectedLabelColor:
                            Colors.white.withValues(alpha: 0.8),
                        labelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 13),
                        unselectedLabelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500, fontSize: 13),
                        tabs: const [
                          Tab(text: 'Quiz History'),
                          Tab(text: 'Mock Exams'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuizHistory(),
                _buildMockHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: Regular Quiz History ───────────────────────────────────────────
  Widget _buildQuizHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: _progressService.getUserResults(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: _accentGreen, strokeWidth: 2.5),
          );
        }
        if (snapshot.hasError) return _buildErrorState();
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history_edu_rounded,
            title: 'No quizzes yet',
            subtitle: 'Complete a quiz and your\nprogress will show up here.',
          );
        }

        final results = snapshot.data!.docs;

        return FadeTransition(
          opacity: _fadeAnimation,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final doc = results[index];
              final data = doc.data() as Map<String, dynamic>;
              final documentId = doc.id;

              final score = data['score'] ?? 0;
              final total = data['totalQuestions'] ?? 1;
              final subject = data['subjectName'] ?? 'General Quiz';
              final double scorePercent =
                  total > 0 ? (score / total) * 100 : 0;
              final color = _scoreColor(scorePercent);
              final label = _scoreLabel(scorePercent);
              final DateTime date = data['timestamp'] != null
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now();

              return Dismissible(
                key: Key(documentId),
                direction: DismissDirection.endToStart,
                background: _dismissBackground(),
                confirmDismiss: (direction) =>
                    _confirmDelete(context, subject),
                onDismissed: (direction) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await FirebaseFirestore.instance
                        .collection('results')
                        .doc(documentId)
                        .delete();
                    messenger.showSnackBar(
                      _snackBar('$subject result deleted', _accentGreen),
                    );
                  } catch (error) {
                    messenger.showSnackBar(
                      _snackBar('Failed to delete: $error',
                          Colors.red.shade600),
                    );
                  }
                },
                child: _quizResultCard(
                  subject: subject,
                  score: score,
                  total: total,
                  scorePercent: scorePercent,
                  color: color,
                  label: label,
                  date: date,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── TAB 2: Mock Exam History ──────────────────────────────────────────────
  Widget _buildMockHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        title: 'Not signed in',
        subtitle: 'Sign in to view your mock exam history.',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('mock_results')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: _accentGreen, strokeWidth: 2.5),
          );
        }
        if (snapshot.hasError) {
          debugPrint('Mock history error: ${snapshot.error}');
          return _buildErrorState();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No mock exams yet',
            subtitle:
                'Complete a JAMB mock exam and\nyour results will appear here.',
          );
        }

        // ── Sort by timestamp descending in Dart ────────────────────
        final results = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
        results.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          // Try takenAt first, then timestamp
          final aTime = aData['takenAt'] as Timestamp? ?? aData['timestamp'] as Timestamp?;
          final bTime = bData['takenAt'] as Timestamp? ?? bData['timestamp'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending
        });

        return FadeTransition(
          opacity: _fadeAnimation,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final doc = results[index];
              final data = doc.data() as Map<String, dynamic>;
              final documentId = doc.id;

              final totalJambScore = (data['totalJambScore'] as num?)?.toDouble() ?? 
                                     (data['totalScore'] as num?)?.toDouble() ?? 0.0;
              final maxScore = (data['maxScore'] as num?)?.toInt() ?? 400;

              // Percentage is based on 400-mark scale
              double percentage;
              final rawPct = data['percentage'];
              if (rawPct is num) {
                percentage = rawPct.toDouble();
              } else if (rawPct is String) {
                percentage = double.tryParse(rawPct) ?? ((totalJambScore / maxScore) * 100);
              } else {
                percentage = (totalJambScore / maxScore) * 100;
              }

              final color = _scoreColor(percentage);
              final label = _scoreLabel(percentage);

              final DateTime date = data['takenAt'] != null
                  ? (data['takenAt'] as Timestamp).toDate()
                  : (data['timestamp'] != null 
                      ? (data['timestamp'] as Timestamp).toDate()
                      : DateTime.now());

              // ✅ Get breakdown from scaledScores (new format) or subjectBreakdown (old format)
              final scaledScores = (data['scaledScores'] as Map<String, dynamic>?) ?? {};
              final maxMarks = (data['maxMarks'] as Map<String, dynamic>?) ?? {};
              final rawScores = (data['rawScores'] as Map<String, dynamic>?) ?? {};
              final totals = (data['totals'] as Map<String, dynamic>?) ?? {};
              
              // Build breakdown from new format if available, otherwise use old format
              final breakdown = scaledScores.isNotEmpty
                  ? scaledScores.entries.map((entry) {
                      final subject = entry.key;
                      final scaled = (entry.value as num?)?.toDouble() ?? 0.0;
                      final max = (maxMarks[subject] as num?)?.toInt() ?? 80;
                      final raw = (rawScores[subject] as num?)?.toInt() ?? 0;
                      final total = (totals[subject] as num?)?.toInt() ?? 40;
                      
                      return {
                        'subjectName': subject,
                        'score': raw,
                        'total': total,
                        'scaled': scaled,
                        'maxMarks': max,
                      };
                    }).toList()
                  : (data['subjectBreakdown'] as List<dynamic>?) ?? [];

              return Dismissible(
                key: Key(documentId),
                direction: DismissDirection.endToStart,
                background: _dismissBackground(),
                confirmDismiss: (direction) =>
                    _confirmDelete(context, 'Mock Exam'),
                onDismissed: (direction) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('mock_results')
                        .doc(documentId)
                        .delete();
                    messenger.showSnackBar(
                      _snackBar('Mock exam result deleted', _accentGreen),
                    );
                  } catch (error) {
                    messenger.showSnackBar(
                      _snackBar('Failed to delete: $error',
                          Colors.red.shade600),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.grey.shade100,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                    strokeWidth: 5,
                                  ),
                                  Text(
                                    '${percentage.toInt()}%',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      color: _darkGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'JAMB Mock Exam',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: _darkGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('MMM dd, yyyy • hh:mm a')
                                        .format(date),
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // ✅ FIXED: Show JAMB score out of 400
                                Text(
                                  '${totalJambScore.toStringAsFixed(1)}/$maxScore',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: color,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    label,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (breakdown.isNotEmpty) ...[
                        Divider(
                            height: 1,
                            color: Colors.grey.shade100,
                            indent: 16),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            children: breakdown.map((item) {
                              final entry =
                                  item as Map<String, dynamic>;
                              final subjectName =
                                  entry['subjectName'] as String? ?? '';
                              final subjectScore =
                                  (entry['score'] as num?)?.toInt() ?? 0;
                              final subjectTotal =
                                  (entry['total'] as num?)?.toInt() ?? 40;
                              
                              // ✅ FIXED: Show scaled JAMB marks for each subject
                              final subjectScaled = (entry['scaled'] as num?)?.toDouble() ?? 0.0;
                              final subjectMaxMarks = (entry['maxMarks'] as num?)?.toInt() ?? 80;
                              
                              final subjectPercent =
                                  (subjectScore / subjectTotal) * 100;
                              final subjectColor =
                                  _scoreColor(subjectPercent);

                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        subjectName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 4,
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: subjectPercent / 100,
                                          backgroundColor:
                                              Colors.grey.shade100,
                                          valueColor:
                                              AlwaysStoppedAnimation<
                                                  Color>(subjectColor),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // ✅ FIXED: Show scaled marks if available, otherwise raw score
                                    Text(
                                      subjectScaled > 0 
                                          ? '${subjectScaled.toStringAsFixed(1)}/$subjectMaxMarks'
                                          : '$subjectScore/$subjectTotal',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: subjectColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────

  Widget _quizResultCard({
    required String subject,
    required int score,
    required int total,
    required double scorePercent,
    required Color color,
    required String label,
    required DateTime date,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: scorePercent / 100,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 5,
                ),
                Text(
                  '${scorePercent.toInt()}%',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: _darkGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score/$total',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.delete_outline, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text('Delete',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String subject) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
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
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade600, size: 26),
              ),
              const SizedBox(height: 16),
              Text('Delete Result?',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkGreen)),
              const SizedBox(height: 8),
              Text(
                  'Remove this $subject result? This cannot be undone.',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.5)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogContext, false),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14)),
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
                      onTap: () => Navigator.pop(dialogContext, true),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6))
                          ],
                        ),
                        child: Center(
                          child: Text('Delete',
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
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 52, color: _accentGreen.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: _darkGreen)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                    height: 1.6),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.error_outline,
                  size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text('Error loading history',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: _darkGreen)),
            const SizedBox(height: 8),
            Text('Please check your connection and try again',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => setState(() {}),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: _accentGreen,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _accentGreen.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Retry',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SnackBar _snackBar(String message, Color color) {
    return SnackBar(
      content:
          Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    );
  }
}