// lib/models/question_model.dart

class Question {
  final String id;
  final String text;
  final String? imagePath;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;
  final String subjectId;
  final String? topic;

  Question({
    required this.id,
    required this.text,
    this.imagePath,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
    required this.subjectId,
    this.topic,
  });

  // Factory constructor to create a Question object from Firestore data
  factory Question.fromFirestore(Map<String, dynamic> data, String id) {
    return Question(
      id: id,
      text: data['text'] ?? 'No Question Text',
      options: List<String>.from(data['options'] ?? []),
      // Handle both 'correctIndex' and 'correctAnswerIndex'
      correctAnswerIndex: data['correctAnswerIndex'] ?? data['correctIndex'] ?? 0,
      explanation: data['explanation'],
      subjectId: data['subjectId'] ?? '',
      topic: data['topic'],
    );
  }

  // Convert to Map for Firestore (if questions need to be saved)
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'options': options,
      'imagePath': imagePath,
      'correctIndex': correctAnswerIndex,
      'explanation': explanation,
      'subjectId': subjectId,
      'topic': topic,
    };
  }
}