// lib/services/mock_exam_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/question_model.dart';

class MockSubject {
  final String id;
  final String name;
  final bool isUnlocked;

  MockSubject({
    required this.id,
    required this.name,
    required this.isUnlocked,
  });
}

class MockExamSession {
  final List<Question> questions;
  final List<MockSubject> subjects;
  final Map<String, int> subjectQuestionCounts; // subjectId -> count

  MockExamSession({
    required this.questions,
    required this.subjects,
    required this.subjectQuestionCounts,
  });

  // Index where a subject's questions start in the flat list
  int subjectStartIndex(String subjectId) {
    int index = 0;
    for (final subject in subjects) {
      if (subject.id == subjectId) return index;
      index += subjectQuestionCounts[subject.id] ?? 0;
    }
    return 0;
  }

  // Which subject does question at [index] belong to?
  MockSubject subjectForIndex(int index) {
    int cursor = 0;
    for (final subject in subjects) {
      final count = subjectQuestionCounts[subject.id] ?? 0;
      if (index < cursor + count) return subject;
      cursor += count;
    }
    return subjects.last;
  }
}

class MockExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int questionsPerSubject = 40;
  static const int timeLimitSeconds = 120 * 60; // 2 hours
  static const String jambScopeId = 'jamb';

  String? get _uid => _auth.currentUser?.uid;

  // ── Fetch all JAMB subjects the user has unlocked ──────────────
  Future<List<MockSubject>> getUnlockedJambSubjects() async {
    try {
      if (_uid == null) return [];

      // Get all JAMB subjects
      final subjectsSnapshot = await _firestore
          .collection('subjects')
          .where('scopeId', isEqualTo: jambScopeId)
          .orderBy('order')
          .get();

      // Get user's unlocked subjects
      final userSubjectsSnapshot = await _firestore
          .collection('user_subjects')
          .where('userId', isEqualTo: _uid)
          .get();

      final unlockedIds = userSubjectsSnapshot.docs
          .map((doc) => doc.data()['subjectId'] as String)
          .toSet();

      // Also include free subjects
      final freeSubjectIds = subjectsSnapshot.docs
          .where((doc) => doc.data()['isFree'] == true)
          .map((doc) => doc.id)
          .toSet();

      final allUnlockedIds = {...unlockedIds, ...freeSubjectIds};

      return subjectsSnapshot.docs
          .where((doc) => allUnlockedIds.contains(doc.id))
          .map((doc) => MockSubject(
                id: doc.id,
                name: doc.data()['name'] ?? '',
                isUnlocked: true,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching unlocked JAMB subjects: $e');
      return [];
    }
  }

  // ── Build a full mock exam session from 4 selected subjects ────
  Future<MockExamSession?> buildMockExam(
      List<MockSubject> selectedSubjects) async {
    try {
      if (selectedSubjects.length != 4) {
        debugPrint('Mock exam requires exactly 4 subjects');
        return null;
      }

      final List<Question> allQuestions = [];
      final Map<String, int> subjectQuestionCounts = {};

      for (final subject in selectedSubjects) {
        final questions =
            await _fetchQuestionsForSubject(subject.id);

        if (questions.isEmpty) {
          debugPrint('No questions found for ${subject.name}');
          return null;
        }

        // Shuffle and take 40
        questions.shuffle();
        final selected = questions.take(questionsPerSubject).toList();
        allQuestions.addAll(selected);
        subjectQuestionCounts[subject.id] = selected.length;

        debugPrint(
            'Loaded ${selected.length} questions for ${subject.name}');
      }

      return MockExamSession(
        questions: allQuestions,
        subjects: selectedSubjects,
        subjectQuestionCounts: subjectQuestionCounts,
      );
    } catch (e) {
      debugPrint('Error building mock exam: $e');
      return null;
    }
  }

  // ── Save mock exam result to Firestore ─────────────────────────
  Future<void> saveMockResult({
    required int totalScore,
    required int totalQuestions,
    required Map<String, int> scorePerSubject,
    required Map<String, int> totalPerSubject,
    required List<MockSubject> subjects,
  }) async {
    try {
      if (_uid == null) return;

      final subjectBreakdown = subjects.map((s) => {
            'subjectId': s.id,
            'subjectName': s.name,
            'score': scorePerSubject[s.id] ?? 0,
            'total': totalPerSubject[s.id] ?? questionsPerSubject,
          }).toList();

      await _firestore
          .collection('mock_results')
          .doc(_uid)
          .collection('sessions')
          .add({
        'totalScore': totalScore,
        'totalQuestions': totalQuestions,
        'percentage':
            ((totalScore / totalQuestions) * 100).toStringAsFixed(1),
        'subjectBreakdown': subjectBreakdown,
        'takenAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving mock result: $e');
    }
  }

  // ── Private: fetch & exclude previously seen questions ─────────
  Future<List<Question>> _fetchQuestionsForSubject(
      String subjectId) async {
    final snapshot = await _firestore
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('scopeId', isEqualTo: jambScopeId)
        .get(const GetOptions(source: Source.serverAndCache));

    List<Question> allQuestions = snapshot.docs
        .map((doc) =>
            Question.fromFirestore(doc.data(), doc.id))
        .toList();

    // Exclude previously seen questions (same logic as quiz_provider)
    if (_uid != null) {
      try {
        final progressDoc = await _firestore
            .collection('quiz_progress')
            .doc(_uid)
            .collection('subjects')
            .doc(subjectId)
            .get();

        if (progressDoc.exists) {
          final usedIds = List<String>.from(
              progressDoc.data()?['usedQuestionIds'] ?? []);
          final fresh = allQuestions
              .where((q) => !usedIds.contains(q.id))
              .toList();

          // Only use fresh pool if enough questions available
          if (fresh.length >= questionsPerSubject) {
            return fresh;
          }
        }
      } catch (e) {
        debugPrint('Could not load used IDs for $subjectId: $e');
      }
    }

    return allQuestions;
  }
}