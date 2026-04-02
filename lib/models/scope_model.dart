// lib/models/scope_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ExamScope {
  final String id;
  final String name;
  final String description;
  final int questionsPerQuiz;
  final int timeLimit; // in seconds
  final int passingScore; // percentage
  
  ExamScope({
    required this.id,
    required this.name,
    required this.description,
    required this.questionsPerQuiz,
    required this.timeLimit,
    required this.passingScore,
  });
  
  factory ExamScope.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamScope(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      questionsPerQuiz: data['questionsPerQuiz'] ?? 40,
      timeLimit: data['timeLimit'] ?? 1800,
      passingScore: data['passingScore'] ?? 50,
    );
  }
}