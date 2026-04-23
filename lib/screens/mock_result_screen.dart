// lib/screens/mock_exam/mock_result_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prep_ng/screens/scope_selection_screen.dart';
import '../../models/question_model.dart';
import '../../services/streak_service.dart';

class MockResultScreen extends StatefulWidget {
  // Raw correct answer counts per subject
  final Map<String, int> rawScores;
  // Scaled JAMB marks per subject (correct × 2.5, max 100 each)
  final Map<String, double> scaledScores;
  // Total questions per subject
  final Map<String, int> totals;
  final Map<String, List<Question>> subjectQuestions;
  final Map<String, Map<int, int>> selectedAnswers;

  const MockResultScreen({
    super.key,
    required this.rawScores,
    required this.scaledScores,
    required this.totals,
    required this.subjectQuestions,
    required this.selectedAnswers,
  });

  @override
  State<MockResultScreen> createState() => _MockResultScreenState();
}

class _MockResultScreenState extends State<MockResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final StreakService _streakService = StreakService();

  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreenFixed = Color(0xFF014104);

  // Each subject max = 100, total max = 400
  static const int _maxMarksPerSubject = 100;
  static const int _totalMaxMarks = 400;

  // Total JAMB score out of 400
  double _totalJambScore = 0;
  // Total raw correct answers
  int _totalRawScore = 0;
  int _totalQuestions = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotals();
    _saveResult();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  void _calculateTotals() {
    widget.scaledScores.forEach((subject, scaled) {
      _totalJambScore += scaled;
    });
    widget.rawScores.forEach((subject, raw) {
      _totalRawScore += raw;
      _totalQuestions += widget.totals[subject] ?? 0;
    });
  }

  // Percentage based on 400-mark scale
  double get _percentage => (_totalJambScore / _totalMaxMarks) * 100;

  Future<void> _saveResult() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('mock_results')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'totalJambScore':
            double.parse(_totalJambScore.toStringAsFixed(1)),
        'totalRawScore': _totalRawScore,
        'totalQuestions': _totalQuestions,
        'maxScore': _totalMaxMarks,
        'percentage': double.parse(_percentage.toStringAsFixed(1)),
        'rawScores': widget.rawScores,
        'scaledScores': widget.scaledScores
            .map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(1)))),
        'totals': widget.totals,
      });

      await _streakService.recordActivity();
      debugPrint('Mock result saved + streak recorded');
    } catch (e) {
      debugPrint('Error saving mock result: $e');
    }
  }

  String _getGrade() {
    if (_percentage >= 80) return 'A';
    if (_percentage >= 70) return 'B';
    if (_percentage >= 60) return 'C';
    if (_percentage >= 50) return 'D';
    if (_percentage >= 40) return 'E';
    return 'F';
  }

  Color _getGradeColor() {
    if (_percentage >= 70) return Colors.green;
    if (_percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getMessage() {
    if (_percentage >= 80) return 'Outstanding Performance! 🎉';
    if (_percentage >= 70) return 'Great Job! Keep it up! 👏';
    if (_percentage >= 60) return 'Good Effort! 💪';
    if (_percentage >= 50) return 'You can do better! 📚';
    return 'More practice needed! 💡';
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
    final textColor = isDark ? Colors.white : const Color(0xFF014104);
    final subtextColor = textColor.withValues(alpha: 0.6);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const ScopeSelectionScreen()),
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentGreen, _darkGreenFixed],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accentGreen.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _getGrade(),
                              style: GoogleFonts.poppins(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getMessage(),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Mock Exam Complete',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Overall Score Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor.withValues(
                                      alpha: isDark ? 0.25 : 0.16),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total Score',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: subtextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: _totalJambScore
                                                    .toStringAsFixed(1),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 32,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  color: textColor,
                                                ),
                                              ),
                                              TextSpan(
                                                text: ' / $_totalMaxMarks',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: subtextColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$_totalRawScore/$_totalQuestions correct',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: subtextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _getGradeColor()
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_percentage.toStringAsFixed(1)}%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _getGradeColor(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: _totalJambScore / _totalMaxMarks,
                                    backgroundColor: theme.dividerColor.withValues(alpha: 0.45),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            _getGradeColor()),
                                    minHeight: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            'SUBJECT BREAKDOWN',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _accentGreen,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),

                          ...widget.rawScores.entries.map((entry) {
                            final subject = entry.key;
                            final rawScore = entry.value;
                            final total = widget.totals[subject] ?? 0;
                            final scaled =
                                widget.scaledScores[subject] ?? 0.0;
                            final subjectPercentage = total > 0
                                ? (rawScore / total) * 100
                                : 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.shadowColor
                                        .withValues(alpha: 0.14),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          subject,
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          // Scaled JAMB marks out of 100
                                          Text(
                                            '${scaled.toStringAsFixed(1)} / $_maxMarksPerSubject',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: _accentGreen,
                                            ),
                                          ),
                                          Text(
                                            '$rawScore/$total correct',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: subtextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value:
                                                subjectPercentage / 100,
                                            backgroundColor:
                                                theme.dividerColor
                                                    .withValues(alpha: 0.45),
                                            valueColor:
                                                AlwaysStoppedAnimation<
                                                    Color>(_accentGreen),
                                            minHeight: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${subjectPercentage.toStringAsFixed(0)}%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: subtextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 20),

                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ScopeSelectionScreen()),
                                (route) => false,
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 58,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF7D),
                                    Color(0xFF2E8B57)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accentGreen
                                        .withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Back to Home',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
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
      ),
    );
  }
}
