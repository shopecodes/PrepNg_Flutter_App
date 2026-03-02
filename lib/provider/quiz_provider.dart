// lib/providers/quiz_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/question_model.dart';

class QuizProvider with ChangeNotifier {
  Timer? _timer; 
  int _timeRemaining = 0; 
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
  
  /// Starts a quiz with dynamic question count and time limit
  /// 
  /// [loadedQuestions] - Pool of questions to select from
  /// [questionsPerQuiz] - How many questions to use (40 for JAMB, 60 for WAEC)
  /// [timeLimitSeconds] - Total time for the quiz in seconds
  void startQuiz(List<Question> loadedQuestions, int questionsPerQuiz, int timeLimitSeconds) {
    // Shuffle the full list and take the specified number of questions
    List<Question> randomizedPool = List.from(loadedQuestions);
    randomizedPool.shuffle();
    
    // Take the specified number of questions (or all if fewer are available)
    _questions = randomizedPool.take(questionsPerQuiz).toList(); 

    _currentQuestionIndex = 0;
    _userAnswers = {};
    _timeRemaining = timeLimitSeconds; // Use the dynamic time limit
    _selectedAnswerIndex = null;
    
    debugPrint('Quiz started with ${_questions.length} questions and ${timeLimitSeconds}s time limit');
    
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
      // If user is on the last question and hits next, trigger finish
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