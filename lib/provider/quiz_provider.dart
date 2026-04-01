// lib/providers/quiz_provider.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/question_model.dart';

class QuizProvider with ChangeNotifier {
  Timer? _timer;
  int _timeRemaining = 0;
  int _totalTime = 0; // ✅ Added: Store the total time limit for timer color calculation
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  Map<int, int> _userAnswers = {};
  VoidCallback? onQuizFinished;

  List<Question> get questions => _questions;
  Question get currentQuestion => _questions[_currentQuestionIndex];
  int get currentQuestionIndex => _currentQuestionIndex;
  int? get selectedAnswerIndex => _selectedAnswerIndex;
  int get timeRemaining => _timeRemaining;
  int get totalTime => _totalTime; // ✅ Added: Getter for total time
  Map<int, int> get userAnswers => _userAnswers;

  int get score {
    int calculatedScore = 0;
    _userAnswers.forEach((questionIndex, selectedIndex) {
      if (questions[questionIndex].correctAnswerIndex == selectedIndex) {
        calculatedScore++;
      }
    });
    return calculatedScore;
  }

  bool get isQuizFinished => _currentQuestionIndex >= _questions.length;

  /// Starts a quiz, excluding previously seen questions per subject.
  /// Resets the used pool automatically when exhausted.
  Future<void> startQuiz(
    List<Question> loadedQuestions,
    int questionsPerQuiz,
    int timeLimitSeconds,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final subjectId = loadedQuestions.first.subjectId;

    List<String> usedIds = [];

    // ── Fetch previously used question IDs for this subject ──────
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('quiz_progress')
            .doc(uid)
            .collection('subjects')
            .doc(subjectId)
            .get();

        if (doc.exists) {
          usedIds = List<String>.from(doc.data()?['usedQuestionIds'] ?? []);
        }
      } catch (e) {
        debugPrint('Could not fetch used question IDs: $e');
        // Non-fatal — just proceed with full pool
      }
    }

    // ── Exclude already-seen questions ───────────────────────────
    List<Question> freshPool =
        loadedQuestions.where((q) => !usedIds.contains(q.id)).toList();

    // ── Reset pool if not enough fresh questions remain ──────────
    if (freshPool.length < questionsPerQuiz) {
      debugPrint(
          'Pool exhausted (${freshPool.length} left), resetting for $subjectId');
      freshPool = List.from(loadedQuestions);
      usedIds = [];
    }

    freshPool.shuffle();
    _questions = freshPool.take(questionsPerQuiz).toList();

    // ── Persist newly used IDs back to Firestore ─────────────────
    if (uid != null) {
      try {
        final newUsedIds = [
          ...usedIds,
          ..._questions.map((q) => q.id),
        ];
        await FirebaseFirestore.instance
            .collection('quiz_progress')
            .doc(uid)
            .collection('subjects')
            .doc(subjectId)
            .set({'usedQuestionIds': newUsedIds});
      } catch (e) {
        debugPrint('Could not save used question IDs: $e');
        // Non-fatal — quiz still runs normally
      }
    }

    _currentQuestionIndex = 0;
    _userAnswers = {};
    _timeRemaining = timeLimitSeconds;
    _totalTime = timeLimitSeconds; // ✅ Added: Store total time for timer color
    _selectedAnswerIndex = null;

    debugPrint(
        'Quiz started: ${_questions.length} questions (${freshPool.length} were available fresh)');

    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        _timeRemaining--;
        notifyListeners();
      } else {
        timer.cancel();
        if (onQuizFinished != null) {
          onQuizFinished!();
        }
      }
    });
  }

  void selectAnswer(int index) {
    _selectedAnswerIndex = index;
    _userAnswers[_currentQuestionIndex] = index;
    notifyListeners();
  }

  void nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      _currentQuestionIndex++;
      _selectedAnswerIndex = _userAnswers[_currentQuestionIndex];
      notifyListeners();
    } else {
      if (onQuizFinished != null) onQuizFinished!();
    }
  }

  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      _selectedAnswerIndex = _userAnswers[_currentQuestionIndex];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}