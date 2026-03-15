// lib/screens/mock_exam/mock_quiz_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  int _secondsRemaining = 9000; // 2.5 hours (150 minutes)
  int _currentSubjectIndex = 0;
  int _currentQuestionIndex = 0;
  // Now stores selected answer INDEX (int) instead of a string letter
  final Map<String, Map<int, int>> _selectedAnswers = {};

  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF014104);

  // Option labels A, B, C, D
  static const List<String> _optionLabels = ['A', 'B', 'C', 'D'];

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

    Map<String, int> scores = {};
    Map<String, int> totals = {};

    widget.subjectQuestions.forEach((subject, questions) {
      int correct = 0;
      final answers = _selectedAnswers[subject]!;

      for (int i = 0; i < questions.length; i++) {
        // Compare selected index with correctAnswerIndex
        if (answers[i] == questions[i].correctAnswerIndex) {
          correct++;
        }
      }

      scores[subject] = correct;
      totals[subject] = questions.length;
    });

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MockResultScreen(
          scores: scores,
          totals: totals,
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
                            onTap: () => _jumpToQuestion(subjectIndex, qIndex),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Exit Mock Exam?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FAF6),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                            color: _darkGreen,
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
                          icon: const Icon(Icons.grid_view_rounded, size: 16),
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
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.subjects.length,
                  itemBuilder: (context, index) {
                    final subject = widget.subjects[index];
                    final isActive = index == _currentSubjectIndex;
                    final answered = _selectedAnswers[subject]?.length ?? 0;
                    final total = widget.subjectQuestions[subject]!.length;

                    return GestureDetector(
                      onTap: () => setState(() {
                        _currentSubjectIndex = index;
                        _currentQuestionIndex = 0;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(
                            right: 12, top: 8, bottom: 8),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color:
                              isActive ? _accentGreen : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              subject,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    isActive ? Colors.white : _darkGreen,
                              ),
                            ),
                            Text(
                              '$answered/$total',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isActive
                                    ? Colors.white.withValues(alpha: 0.9)
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_currentQuestionIndex + 1} of ${_currentQuestions.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // FIX 1: was _currentQuestion.questionText → now .text
                      Text(
                        _currentQuestion.text,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _darkGreen,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // FIX 2: was options.entries.map → now options.asMap().entries.map
                      // FIX 3: comparison now uses index vs correctAnswerIndex
                      ..._currentQuestion.options.asMap().entries.map((entry) {
                        final optionIndex = entry.key;
                        final optionText = entry.value;
                        final isSelected =
                            _selectedAnswers[_currentSubject]
                                    ?[_currentQuestionIndex] ==
                                optionIndex;

                        return GestureDetector(
                          onTap: () => _selectAnswer(optionIndex),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _accentGreen.withValues(alpha: 0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? _accentGreen
                                    : Colors.grey.shade200,
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
                                        : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      // Show A, B, C, D label
                                      optionIndex < _optionLabels.length
                                          ? _optionLabels[optionIndex]
                                          : '${optionIndex + 1}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : _darkGreen,
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
                                      color: _darkGreen,
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
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
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
      ),
    );
  }
}