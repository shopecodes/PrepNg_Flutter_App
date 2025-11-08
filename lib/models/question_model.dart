// lib/models/question_model.dart

class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctAnswerIndex; // Index of the correct answer in the options list

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctAnswerIndex,
  });

  // Factory constructor to create a Question object from Firestore data
  factory Question.fromFirestore(Map<String, dynamic> data, String id) {
    return Question(
      id: id,
      text: data['text'] ?? 'No Question Text', // Use a default if text is missing
      // Ensure options is treated as a list of strings
      options: List<String>.from(data['options'] ?? []), 
      correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
    );
  }
}