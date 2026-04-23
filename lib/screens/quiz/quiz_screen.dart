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

  StreamSubscription<Set<String>>? _bookmarkSubscription;

  static const Color _accentGreen = Color(0xFF4CAF7D);

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

    _bookmarkSubscription = _bookmarkService.bookmarkedIdsStream().listen((ids) {
      if (mounted) setState(() => _bookmarkedIds = ids);
    });
  }

  @override
  void dispose() {
    Provider.of<QuizProvider>(context, listen: false).onQuizFinished = null;
    _questionAnimController.dispose();
    _bookmarkSubscription?.cancel();
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

  // ── Smart image widget: handles URL, asset path, or empty ────────────────
  Widget _buildQuestionImage(String imagePath) {
    final isUrl = imagePath.startsWith('http://') ||
        imagePath.startsWith('https://');

    Widget imageWidget;

    if (isUrl) {
      imageWidget = Image.network(
        imagePath,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: _accentGreen,
                strokeWidth: 2.5,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _imageFallback(),
      );
    } else {
      imageWidget = Image.asset(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _imageFallback(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageWidget,
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            'Image not available',
            style: GoogleFonts.poppins(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
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
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4CAF7D))),
          );
        }

        final question = quizProvider.currentQuestion;

        // ✅ Fixed: was ~/ 90 (wrong), now ~/ 60 (correct)
        final int minutes = quizProvider.timeRemaining ~/ 60;
        final int seconds = quizProvider.timeRemaining % 60;
        final String timerText =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        // ✅ Fixed: totalTime derived from actual quiz time set at start,
        // not guessed from question count.
        // Use of English = 60 questions = 30 min (1800s)
        // Other JAMB subjects = 40 questions = 20 min (1200s)
        // quizProvider.totalTime holds the value passed into startQuiz()
        final int totalTime = quizProvider.totalTime;
        final timerColor =
            _timerColor(quizProvider.timeRemaining, totalTime);
        final double progressValue =
            (quizProvider.currentQuestionIndex + 1) /
                quizProvider.questions.length;

        final isBookmarked = _bookmarkedIds.contains(question.id);

        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                              color: Theme.of(context).colorScheme.onSurface,
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
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isBookmarked
                                    ? _accentGreen.withValues(alpha: 0.4)
                                    : Theme.of(context).dividerColor,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).shadowColor.withValues(alpha: 0.14),
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
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor:
                                Theme.of(context).dividerColor.withValues(alpha: 0.45),
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
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .shadowColor
                                          .withValues(alpha: 0.18),
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
                                    color: Theme.of(context).colorScheme.onSurface,
                                    height: 1.5,
                                  ),
                                ),
                              ),

                              // ── Smart image: URL or asset ─────
                              if (question.imagePath != null &&
                                  question.imagePath!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildQuestionImage(question.imagePath!),
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
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accentGreen : Theme.of(context).dividerColor,
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
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.14),
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
                color: isSelected
                    ? _accentGreen
                    : Theme.of(context).dividerColor.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode('A'.codeUnitAt(0) + index),
                  style: GoogleFonts.poppins(
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
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
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.85),
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
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.18),
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
                    ? Theme.of(context).dividerColor.withValues(alpha: 0.45)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFirstQuestion
                      ? Theme.of(context).dividerColor
                      : Theme.of(context).dividerColor.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isFirstQuestion
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
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
