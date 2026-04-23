// lib/screens/quiz/result_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/question_model.dart';
import '../../services/progress_service.dart';
import '../../services/streak_service.dart';
import '../../services/leaderboard_service.dart';
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
  final StreakService _streakService = StreakService();
  final LeaderboardService _leaderboardService = LeaderboardService();
  bool _isSaved = false;

  late AnimationController _animController;
  late Animation<double> _scoreAnimation;
  late Animation<double> _fadeAnimation;

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

      await _streakService.recordActivity();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = userDoc.data();
        final displayName = data?['displayName'] ?? 'Anonymous';
        final department = data?['department'] ?? 'Science';

        await _leaderboardService.recordScore(
          score: widget.score,
          totalQuestions: widget.questions.length,
          displayName: displayName,
          department: department,
        );
      }

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _scoreColor,
                    _scoreColor.withValues(alpha: 0.75)
                  ],
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
                                    value: animatedScore / 100,
                                    backgroundColor: Colors.white
                                        .withValues(alpha: 0.25),
                                    valueColor:
                                        const AlwaysStoppedAnimation<
                                            Color>(Colors.white),
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
                                  color: Colors.white
                                      .withValues(alpha: 0.2),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                        Icons.cloud_done_rounded,
                                        color: Colors.white,
                                        size: 14),
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
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
                      subjectName: widget.subjectName,
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.18),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

// ── Review Tile ───────────────────────────────────────────────────────────────

class _ReviewTile extends StatefulWidget {
  final Question question;
  final int? userAnswer;
  final bool isCorrect;
  final int index;
  final String subjectName;

  const _ReviewTile({
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
    required this.index,
    required this.subjectName,
  });

  @override
  State<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<_ReviewTile> {
  static const Color _accentGreen = Color(0xFF4CAF7D);

  bool _isFlagged = false;
  bool _isSubmittingFlag = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyFlagged();
  }

  Future<void> _checkIfAlreadyFlagged() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final existingFlag = await FirebaseFirestore.instance
          .collection('flagged_questions')
          .where('questionId', isEqualTo: widget.question.id)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isFlagged = existingFlag.docs.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error checking flag status: $e');
    }
  }

  Future<void> _showFlagDialog() async {
    final TextEditingController reasonController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to flag questions')),
      );
      return;
    }

    // Use showModalBottomSheet instead of showGeneralDialog.
    // This natively handles keyboard insets — the sheet slides up
    // with the keyboard automatically, with no overflow or debug stripes.
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // essential: allows the sheet to resize for keyboard
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _FlagDialogSheet(reasonController: reasonController);
      },
    );

    if (result == true && reasonController.text.trim().isNotEmpty) {
      await _submitFlag(reasonController.text.trim());
    }
  }

  Future<void> _submitFlag(String reason) async {
    setState(() => _isSubmittingFlag = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userEmail =
          userDoc.data()?['email'] ?? user.email ?? 'unknown';

      await FirebaseFirestore.instance
          .collection('flagged_questions')
          .add({
        'questionId': widget.question.id,
        'questionText': widget.question.text,
        'options': widget.question.options,
        'userAnswer': widget.userAnswer != null
            ? widget.question.options[widget.userAnswer!]
            : 'No answer',
        'correctAnswer':
            widget.question.options[widget.question.correctAnswerIndex],
        'userAnswerIndex': widget.userAnswer,
        'correctAnswerIndex': widget.question.correctAnswerIndex,
        'userExplanation': reason,
        'subjectName': widget.subjectName,
        'userId': user.uid,
        'userEmail': userEmail,
        'flaggedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        setState(() {
          _isFlagged = true;
          _isSubmittingFlag = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Question reported! We\'ll review it soon.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting flag: $e');
      if (mounted) {
        setState(() => _isSubmittingFlag = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit report. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color tileColor =
        widget.isCorrect ? _accentGreen : Colors.red.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.14),
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
              widget.isCorrect
                  ? Icons.check_rounded
                  : Icons.close_rounded,
              color: tileColor,
              size: 20,
            ),
          ),
          title: Text(
            widget.question.text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              widget.isCorrect ? 'Correct' : 'Incorrect',
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
                color: Theme.of(context).dividerColor.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _answerRow(
                    label: 'Your Answer',
                    answer: widget.userAnswer != null
                        ? widget.question.options[widget.userAnswer!]
                        : 'No answer',
                    color: widget.isCorrect
                        ? _accentGreen
                        : Colors.red.shade400,
                    icon: widget.isCorrect
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                  ),
                  if (!widget.isCorrect) ...[
                    const SizedBox(height: 10),
                    _answerRow(
                      label: 'Correct Answer',
                      answer: widget.question
                          .options[widget.question.correctAnswerIndex],
                      color: _accentGreen,
                      icon: Icons.check_circle_rounded,
                    ),
                  ],
                  if (widget.question.explanation != null) ...[
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
                              size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.question.explanation!,
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
                  if (!widget.isCorrect) ...[
                    const SizedBox(height: 14),
                    if (_isFlagged)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.shade200, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.flag,
                                size: 14,
                                color: Colors.orange.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'You\'ve reported this question',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap:
                            _isSubmittingFlag ? null : _showFlagDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.orange.shade300,
                                width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSubmittingFlag)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            Colors.orange.shade600),
                                  ),
                                )
                              else
                                Icon(Icons.flag_outlined,
                                    size: 15,
                                    color: Colors.orange.shade600),
                              const SizedBox(width: 6),
                              Text(
                                _isSubmittingFlag
                                    ? 'Submitting...'
                                    : 'Report Problem',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
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

// ── Flag Dialog Sheet ─────────────────────────────────────────────────────────
// Extracted into its own StatefulWidget so it has its own BuildContext
// and can read keyboard insets correctly via MediaQuery.of(context).

class _FlagDialogSheet extends StatefulWidget {
  final TextEditingController reasonController;

  const _FlagDialogSheet({required this.reasonController});

  @override
  State<_FlagDialogSheet> createState() => _FlagDialogSheetState();
}

class _FlagDialogSheetState extends State<_FlagDialogSheet> {
  static const Color _accentGreen = Color(0xFF4CAF7D);

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom is the keyboard height — reads correctly here
    // because showModalBottomSheet forwards MediaQuery into the sheet.
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // This single padding is all that's needed — pushes the whole
      // sheet up by exactly the keyboard height, no overflow, no stripes.
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Report Problem',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'What\'s the issue with this question?',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.reasonController,
                  maxLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText:
                        'Example:\n- Wrong answer marked as correct\n- Correct answer not in options\n- Question is unclear',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _accentGreen, width: 2),
                    ),
                  ),
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (widget.reasonController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Please describe the issue')),
                          );
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Submit Report',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
