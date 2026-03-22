// lib/services/quiz_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question_model.dart'; 
import 'package:flutter/foundation.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Added scopeId to ensure getting the right exam type (JAMB vs WAEC)
  Future<List<Question>> loadQuestions(String subjectId, String scopeId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('questions')
          .where('subjectId', isEqualTo: subjectId)
          .where('scopeId', isEqualTo: scopeId) // Critical for JAMB/WAEC separation
          .get(const GetOptions(source: Source.serverAndCache)); // For offline access

      if (snapshot.docs.isEmpty) {
        throw Exception("No questions found. Check subjectId: $subjectId and scopeId: $scopeId");
      }

      // Use the factory constructor we just fixed!
      return snapshot.docs.map((doc) {
        return Question.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

    } catch (e) {
      if (kDebugMode) {
        print('Error loading questions: $e');
      }
      rethrow;
    }
  }
}