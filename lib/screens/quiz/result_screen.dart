// lib/screens/quiz/result_screen.dart

import 'package:flutter/material.dart';
import '../../models/question_model.dart';
import '../../services/progress_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultScreen extends StatefulWidget {
  final String subjectName;
  final List<Question> questions;
  final Map<int, int> userAnswers;
  final int score;

  const ResultScreen({
    super.key,
    required this.subjectName,
    required this.questions,
    required this.userAnswers,
    required this.score,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  final ProgressService _progressService = ProgressService();
  bool _isSaved = false;

  late AnimationController _animController;
  late Animation<double> _scoreAnimation;
  late Animation<double> _fadeAnimation;

  // Color palette
  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);

  double get _percentage =>
      (widget.score / widget.questions.length) * 100;

  Color get _scoreColor {
    if (_percentage >= 70) return _accentGreen;
    if (_percentage >= 50) return const Color(0xFFE89B4A);
    return Colors.red.shade500;
  }

  String get _scoreEmoji {
    if (_percentage >= 70) return '🎉';
    if (_percentage >= 50) return '👍';
    return '📚';
  }

  String get _scoreMessage {
    if (_percentage >= 70) return 'Excellent Work!';
    if (_percentage >= 50) return 'Good Effort!';
    return 'Keep Practicing!';
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scoreAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
    _animController.forward();
    _saveFinalResults();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _saveFinalResults() async {
    try {
      await _progressService.saveQuizResult(
        subjectName: widget.subjectName,
        score: widget.score,
        totalQuestions: widget.questions.length,
      );
      if (mounted) setState(() => _isSaved = true);
    } catch (e) {
      debugPrint("Error saving results: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: Column(
          children: [
            // ── Score Header ──────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_scoreColor, _scoreColor.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _scoreColor.withValues(alpha: 0.35),
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
                      // Subject label
                      Text(
                        widget.subjectName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Animated score ring
                      AnimatedBuilder(
                        animation: _scoreAnimation,
                        builder: (context, child) {
                          final animatedScore =
                              (_percentage * _scoreAnimation.value);
                          return SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: CircularProgressIndicator(
                                    value:
                                        animatedScore / 100,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.25),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                    strokeWidth: 10,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${animatedScore.toInt()}%',
                                      style: GoogleFonts.poppins(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${widget.score}/${widget.questions.length}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Message + emoji
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              '$_scoreEmoji $_scoreMessage',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            if (_isSaved) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cloud_done_rounded,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Progress Saved',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Review Label ─────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REVIEW ANSWERS',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _accentGreen,
                        letterSpacing: 2,
                      ),
                    ),
                    // Quick stats
                    Row(
                      children: [
                        _statPill(
                          icon: Icons.check_rounded,
                          label: '${widget.score} correct',
                          color: _accentGreen,
                        ),
                        const SizedBox(width: 8),
                        _statPill(
                          icon: Icons.close_rounded,
                          label:
                              '${widget.questions.length - widget.score} wrong',
                          color: Colors.red.shade400,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Questions Review List ─────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  itemCount: widget.questions.length,
                  itemBuilder: (context, index) {
                    final question = widget.questions[index];
                    final userAnswer = widget.userAnswers[index];
                    final isCorrect =
                        userAnswer == question.correctAnswerIndex;

                    return _ReviewTile(
                      question: question,
                      userAnswer: userAnswer,
                      isCorrect: isCorrect,
                      index: index,
                    );
                  },
                ),
              ),
            ),

            // ── Go Home Button ────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _accentGreen,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _accentGreen.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.home_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Finish & Go Home',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(
      {required IconData icon,
      required String label,
      required Color color}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review Tile ────────────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  final Question question;
  final int? userAnswer;
  final bool isCorrect;
  final int index;

  const _ReviewTile({
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
    required this.index,
  });

  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);
  static const Color _bgColor = Color(0xFFF5FAF6);

  @override
  Widget build(BuildContext context) {
    final Color tileColor =
        isCorrect ? _accentGreen : Colors.red.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tileColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCorrect ? Icons.check_rounded : Icons.close_rounded,
              color: tileColor,
              size: 20,
            ),
          ),
          title: Text(
            question.text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _darkGreen,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              isCorrect ? 'Correct' : 'Incorrect',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tileColor,
              ),
            ),
          ),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Your answer
                  _answerRow(
                    label: 'Your Answer',
                    answer: userAnswer != null
                        ? question.options[userAnswer!]
                        : 'No answer',
                    color: isCorrect ? _accentGreen : Colors.red.shade400,
                    icon: isCorrect
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                  ),

                  if (!isCorrect) ...[
                    const SizedBox(height: 10),
                    // Correct answer
                    _answerRow(
                      label: 'Correct Answer',
                      answer: question
                          .options[question.correctAnswerIndex],
                      color: _accentGreen,
                      icon: Icons.check_circle_rounded,
                    ),
                  ],

                  // Explanation
                  if (question.explanation != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFBBD9F5), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              size: 16,
                              color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              question.explanation!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue.shade800,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerRow({
    required String label,
    required String answer,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                TextSpan(
                  text: answer,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}