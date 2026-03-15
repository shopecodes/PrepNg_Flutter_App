// lib/screens/quiz/quiz_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prep_ng/provider/quiz_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bookmark_service.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  final String subjectName;

  const QuizScreen({
    super.key,
    required this.subjectName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _questionAnimController;
  late Animation<double> _questionFadeAnimation;
  late Animation<Offset> _questionSlideAnimation;

  final BookmarkService _bookmarkService = BookmarkService();
  Set<String> _bookmarkedIds = {};
  bool _isTogglingBookmark = false;

  // ── Store subscription so it can be cancelled ─────────────────
  StreamSubscription<Set<String>>? _bookmarkSubscription;

  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  void _navigateToResults(QuizProvider provider) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          subjectName: widget.subjectName,
          questions: provider.questions,
          userAnswers: provider.userAnswers,
          score: provider.score,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _questionAnimController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _questionFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _questionAnimController, curve: Curves.easeOut),
    );
    _questionSlideAnimation =
        Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _questionAnimController, curve: Curves.easeOut));
    _questionAnimController.forward();

    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    quizProvider.onQuizFinished = () => _navigateToResults(quizProvider);

    // ── Store subscription so we can cancel it in dispose ────────
    _bookmarkSubscription = _bookmarkService.bookmarkedIdsStream().listen((ids) {
      if (mounted) setState(() => _bookmarkedIds = ids);
    });
  }

  @override
  void dispose() {
    Provider.of<QuizProvider>(context, listen: false).onQuizFinished = null;
    _questionAnimController.dispose();
    _bookmarkSubscription?.cancel(); // ← properly cancel stream
    super.dispose();
  }

  void _animateQuestionChange(VoidCallback action) {
    _questionAnimController.reverse().then((_) {
      action();
      _questionAnimController.forward();
    });
  }

  Future<void> _toggleBookmark(QuizProvider provider) async {
    if (_isTogglingBookmark) return;
    setState(() => _isTogglingBookmark = true);

    final question = provider.currentQuestion;
    await _bookmarkService.toggleBookmark(question, widget.subjectName);

    if (mounted) setState(() => _isTogglingBookmark = false);
  }

  Color _timerColor(int timeRemaining, int totalTime) {
    final ratio = timeRemaining / totalTime;
    if (ratio > 0.5) return _accentGreen;
    if (ratio > 0.25) return const Color(0xFFE89B4A);
    return Colors.red.shade500;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuizProvider>(
      builder: (context, quizProvider, child) {
        if (quizProvider.isQuizFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (quizProvider.onQuizFinished != null) {
              quizProvider.onQuizFinished!();
            }
          });
          return const Scaffold(
            backgroundColor: Color(0xFFF5FAF6),
            body: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4CAF7D))),
          );
        }

        final question = quizProvider.currentQuestion;
        final int minutes = quizProvider.timeRemaining ~/ 60;
        final int seconds = quizProvider.timeRemaining % 60;
        final String timerText =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        final int totalTime = quizProvider.questions.length <= 40
            ? 30 * 60
            : 60 * 60;
        final timerColor =
            _timerColor(quizProvider.timeRemaining, totalTime);
        final double progressValue =
            (quizProvider.currentQuestionIndex + 1) /
                quizProvider.questions.length;

        final isBookmarked = _bookmarkedIds.contains(question.id);

        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: _bgColor,
            body: SafeArea(
              child: Column(
                children: [
                  // ── Top Bar ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.subjectName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _darkGreen,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Bookmark button
                        GestureDetector(
                          onTap: () => _toggleBookmark(quizProvider),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: isBookmarked
                                  ? _accentGreen.withValues(alpha: 0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isBookmarked
                                    ? _accentGreen.withValues(alpha: 0.4)
                                    : Colors.grey.shade200,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _isTogglingBookmark
                                ? Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _accentGreen,
                                    ),
                                  )
                                : Icon(
                                    isBookmarked
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    size: 20,
                                    color: isBookmarked
                                        ? _accentGreen
                                        : Colors.grey.shade400,
                                  ),
                          ),
                        ),

                        // Timer pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: timerColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: timerColor.withValues(alpha: 0.3),
                                width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  size: 16, color: timerColor),
                              const SizedBox(width: 6),
                              Text(
                                timerText,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: timerColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Progress bar ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question ${quizProvider.currentQuestionIndex + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _accentGreen,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${quizProvider.currentQuestionIndex + 1} / ${quizProvider.questions.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                _accentGreen),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Question + Options ────────────────────────
                  Expanded(
                    child: FadeTransition(
                      opacity: _questionFadeAnimation,
                      child: SlideTransition(
                        position: _questionSlideAnimation,
                        child: SingleChildScrollView(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Question card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.06),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  question.text,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _darkGreen,
                                    height: 1.5,
                                  ),
                                ),
                              ),

                              // Optional image
                              if (question.imagePath != null &&
                                  question.imagePath!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    child: Image.asset(
                                      question.imagePath!,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          padding:
                                              const EdgeInsets.all(16),
                                          color: Colors.grey.shade100,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image,
                                                  color: Colors
                                                      .grey.shade400),
                                              const SizedBox(width: 8),
                                              Text('Image not found',
                                                  style:
                                                      GoogleFonts.poppins(
                                                          color: Colors
                                                              .grey
                                                              .shade400)),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Options
                              ...List.generate(
                                  question.options.length, (index) {
                                final isSelected =
                                    index ==
                                        quizProvider.selectedAnswerIndex;
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10),
                                  child: _OptionTile(
                                    text: question.options[index],
                                    index: index,
                                    isSelected: isSelected,
                                    onTap: () =>
                                        quizProvider.selectAnswer(index),
                                  ),
                                );
                              }),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Navigation Bar ────────────────────────────
                  _QuizNavigationBar(
                    quizProvider: quizProvider,
                    onPrevious: () => _animateQuestionChange(
                        quizProvider.previousQuestion),
                    onNext: () => _animateQuestionChange(
                        quizProvider.nextQuestion),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Option Tile ────────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final String text;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.text,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentGreen.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accentGreen : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _accentGreen.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? _accentGreen : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode('A'.codeUnitAt(0) + index),
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.grey.shade500,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isSelected ? _darkGreen : Colors.grey.shade700,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded,
                  color: _accentGreen, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Navigation Bar ─────────────────────────────────────────────────────────────

class _QuizNavigationBar extends StatelessWidget {
  final QuizProvider quizProvider;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _QuizNavigationBar({
    required this.quizProvider,
    required this.onPrevious,
    required this.onNext,
  });

  static const Color _accentGreen = Color(0xFF4CAF7D);

  @override
  Widget build(BuildContext context) {
    final isLastQuestion = quizProvider.currentQuestionIndex ==
        quizProvider.questions.length - 1;
    final isFirstQuestion = quizProvider.currentQuestionIndex == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
      child: Row(
        children: [
          GestureDetector(
            onTap: isFirstQuestion ? null : onPrevious,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isFirstQuestion
                    ? Colors.grey.shade100
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFirstQuestion
                      ? Colors.grey.shade200
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isFirstQuestion
                    ? Colors.grey.shade300
                    : Colors.grey.shade600,
                size: 22,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isLastQuestion) {
                  if (quizProvider.onQuizFinished != null) {
                    quizProvider.onQuizFinished!();
                  }
                } else {
                  onNext();
                }
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isLastQuestion
                      ? Colors.red.shade500
                      : _accentGreen,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isLastQuestion
                              ? Colors.red.shade500
                              : _accentGreen)
                          .withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLastQuestion ? 'Submit Quiz' : 'Next Question',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLastQuestion
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}