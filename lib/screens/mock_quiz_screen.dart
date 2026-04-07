// lib/screens/mock_exam/mock_quiz_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../provider/theme_provider.dart';
import '../../models/question_model.dart';
import 'mock_result_screen.dart';

class MockQuizScreen extends StatefulWidget {
  final Map<String, List<Question>> subjectQuestions;
  final List<String> subjects;

  const MockQuizScreen({
    super.key,
    required this.subjectQuestions,
    required this.subjects,
    required List<String> selectedSubjectIds,
  });

  @override
  State<MockQuizScreen> createState() => _MockQuizScreenState();
}

class _MockQuizScreenState extends State<MockQuizScreen> {
  late Timer _timer;
  int _secondsRemaining = 7200; // 2 hours
  int _currentSubjectIndex = 0;
  int _currentQuestionIndex = 0;

  final Map<String, Map<int, int>> _selectedAnswers = {};

  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF014104);
  static const List<String> _optionLabels = ['A', 'B', 'C', 'D'];

  // ── JAMB scoring weights ─────────────────────────────────────────────────
  // Use of English: 60 questions → 160 marks (each correct = 160/60 ≈ 2.667)
  // Other subjects: 40 questions → 80 marks each (each correct = 80/40 = 2.0)
  // Total = 160 + 80 + 80 + 80 = 400 marks
  static const int _useOfEnglishMaxMarks = 160;
  static const int _otherSubjectMaxMarks = 80;

  /// Returns the max JAMB marks for a subject based on its question count.
  /// Use of English has 60 questions → 160 marks.
  /// All other subjects have 40 questions → 80 marks.
  int _maxMarksForSubject(String subject) {
    final questionCount = widget.subjectQuestions[subject]?.length ?? 0;
    return questionCount == 60 ? _useOfEnglishMaxMarks : _otherSubjectMaxMarks;
  }

  /// Converts raw correct count to scaled JAMB marks for a subject.
  /// e.g. 45/60 correct for Use of English = (45/60) × 160 = 120 marks
  double _scaledScore(String subject, int correctCount) {
    final total = widget.subjectQuestions[subject]?.length ?? 1;
    final maxMarks = _maxMarksForSubject(subject);
    return (correctCount / total) * maxMarks;
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    for (var subject in widget.subjects) {
      _selectedAnswers[subject] = {};
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _submitExam();
      }
    });
  }

  String get _currentSubject => widget.subjects[_currentSubjectIndex];
  List<Question> get _currentQuestions =>
      widget.subjectQuestions[_currentSubject]!;
  Question get _currentQuestion => _currentQuestions[_currentQuestionIndex];

  void _selectAnswer(int answerIndex) {
    setState(() {
      _selectedAnswers[_currentSubject]![_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _currentQuestions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else if (_currentSubjectIndex < widget.subjects.length - 1) {
      setState(() {
        _currentSubjectIndex++;
        _currentQuestionIndex = 0;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    } else if (_currentSubjectIndex > 0) {
      setState(() {
        _currentSubjectIndex--;
        _currentQuestionIndex =
            widget.subjectQuestions[widget.subjects[_currentSubjectIndex]]!
                    .length -
                1;
      });
    }
  }

  void _jumpToQuestion(int subjectIndex, int questionIndex) {
    setState(() {
      _currentSubjectIndex = subjectIndex;
      _currentQuestionIndex = questionIndex;
    });
    Navigator.pop(context);
  }

  int _getTotalAnswered() {
    int total = 0;
    _selectedAnswers.forEach((subject, answers) {
      total += answers.length;
    });
    return total;
  }

  void _submitExam() {
    _timer.cancel();

    // Raw correct counts — used for subject breakdown display
    final Map<String, int> rawScores = {};
    // Scaled JAMB marks — used for total out of 400
    final Map<String, double> scaledScores = {};
    final Map<String, int> totals = {};
    final Map<String, int> maxMarks = {};

    widget.subjectQuestions.forEach((subject, questions) {
      int correct = 0;
      final answers = _selectedAnswers[subject]!;
      for (int i = 0; i < questions.length; i++) {
        if (answers[i] == questions[i].correctAnswerIndex) {
          correct++;
        }
      }
      rawScores[subject] = correct;
      scaledScores[subject] = _scaledScore(subject, correct);
      totals[subject] = questions.length;
      maxMarks[subject] = _maxMarksForSubject(subject);
    });

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MockResultScreen(
          rawScores: rawScores,
          scaledScores: scaledScores,
          totals: totals,
          maxMarks: maxMarks,
          subjectQuestions: widget.subjectQuestions,
          selectedAnswers: _selectedAnswers,
        ),
      ),
    );
  }

  void _showNavigationGrid() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Question Navigation',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.subjects.length,
                itemBuilder: (context, subjectIndex) {
                  final subject = widget.subjects[subjectIndex];
                  final questions = widget.subjectQuestions[subject]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _darkGreen,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: questions.length,
                        itemBuilder: (context, qIndex) {
                          final isAnswered =
                              _selectedAnswers[subject]!.containsKey(qIndex);
                          final isCurrent = subjectIndex ==
                                  _currentSubjectIndex &&
                              qIndex == _currentQuestionIndex;

                          return GestureDetector(
                            onTap: () =>
                                _jumpToQuestion(subjectIndex, qIndex),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? _accentGreen
                                    : isAnswered
                                        ? Colors.green.shade100
                                        : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCurrent
                                      ? _darkGreen
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${qIndex + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isCurrent
                                        ? Colors.white
                                        : isAnswered
                                            ? _darkGreen
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text('Image not available',
              style: GoogleFonts.poppins(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _secondsRemaining ~/ 3600;
    final minutes = (_secondsRemaining % 3600) ~/ 60;
    final seconds = _secondsRemaining % 60;

    final totalQuestions =
        widget.subjectQuestions.values.fold(0, (sum, q) => sum + q.length);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text('Exit Mock Exam?',
                style:
                    GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text(
              'Your progress will be lost. Are you sure?',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if ((shouldExit ?? false) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Builder(builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
        final bgColor =
            isDark ? const Color(0xFF121817) : const Color(0xFFF5FAF6);
        final cardColor = isDark ? const Color(0xFF1E2625) : Colors.white;
        final textColor =
            isDark ? Colors.white : const Color(0xFF014104);
        final subtextColor =
            isDark ? Colors.white60 : Colors.grey.shade600;

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mock Exam',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _secondsRemaining < 600
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: _secondsRemaining < 600
                                      ? Colors.red.shade700
                                      : _accentGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _secondsRemaining < 600
                                        ? Colors.red.shade700
                                        : _darkGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_getTotalAnswered()} / $totalQuestions answered',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showNavigationGrid,
                            icon: const Icon(Icons.grid_view_rounded,
                                size: 16),
                            label: const Text('Navigate'),
                            style: TextButton.styleFrom(
                              foregroundColor: _accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Subject tabs
                Container(
                  height: 60,
                  color: cardColor,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.subjects.length,
                    itemBuilder: (context, index) {
                      final subject = widget.subjects[index];
                      final isActive = index == _currentSubjectIndex;
                      final answered =
                          _selectedAnswers[subject]?.length ?? 0;
                      final total =
                          widget.subjectQuestions[subject]!.length;

                      return GestureDetector(
                        onTap: () => setState(() {
                          _currentSubjectIndex = index;
                          _currentQuestionIndex = 0;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(
                              right: 12, top: 8, bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          decoration: BoxDecoration(
                            color: isActive
                                ? _accentGreen
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                subject,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : textColor,
                                ),
                              ),
                              Text(
                                '$answered/$total',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isActive
                                      ? Colors.white
                                          .withValues(alpha: 0.9)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Question
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Question ${_currentQuestionIndex + 1} of ${_currentQuestions.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentQuestion.text,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            height: 1.5,
                          ),
                        ),
                        if (_currentQuestion.imagePath != null &&
                            _currentQuestion.imagePath!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildQuestionImage(
                              _currentQuestion.imagePath!),
                        ],
                        const SizedBox(height: 24),
                        ..._currentQuestion.options
                            .asMap()
                            .entries
                            .map((entry) {
                          final optionIndex = entry.key;
                          final optionText = entry.value;
                          final isSelected =
                              _selectedAnswers[_currentSubject]
                                      ?[_currentQuestionIndex] ==
                                  optionIndex;

                          return GestureDetector(
                            onTap: () => _selectAnswer(optionIndex),
                            child: Container(
                              margin:
                                  const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _accentGreen
                                        .withValues(alpha: 0.1)
                                    : cardColor,
                                borderRadius:
                                    BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? _accentGreen
                                      : (isDark
                                          ? Colors.white12
                                          : Colors.grey.shade200),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _accentGreen
                                          : (isDark
                                              ? Colors.white10
                                              : Colors.grey.shade100),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        optionIndex <
                                                _optionLabels.length
                                            ? _optionLabels[
                                                optionIndex]
                                            : '${optionIndex + 1}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : textColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      optionText,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: textColor,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Navigation buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_currentQuestionIndex > 0 ||
                          _currentSubjectIndex > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousQuestion,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              side: BorderSide(color: _accentGreen),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Previous',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _accentGreen,
                              ),
                            ),
                          ),
                        ),
                      if (_currentQuestionIndex > 0 ||
                          _currentSubjectIndex > 0)
                        const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _currentQuestionIndex ==
                                      _currentQuestions.length - 1 &&
                                  _currentSubjectIndex ==
                                      widget.subjects.length - 1
                              ? _submitExam
                              : _nextQuestion,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            backgroundColor: _accentGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentQuestionIndex ==
                                        _currentQuestions.length - 1 &&
                                    _currentSubjectIndex ==
                                        widget.subjects.length - 1
                                ? 'Submit Exam'
                                : 'Next',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}