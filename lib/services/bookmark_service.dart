// lib/services/bookmark_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/question_model.dart';

class BookmarkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference? get _bookmarksRef {
    if (_uid == null) return null;
    return _firestore.collection('users').doc(_uid).collection('bookmarks');
  }

  Future<bool> addBookmark(Question question, String subjectName) async {
    try {
      if (_uid == null) return false;
      await _bookmarksRef!.doc(question.id).set({
        'questionId': question.id,
        'bookmarkedAt': FieldValue.serverTimestamp(), // ← was 'savedAt'
        'text': question.text,
        'options': question.options,
        'correctAnswerIndex': question.correctAnswerIndex,
        'explanation': question.explanation,
        'subjectId': question.subjectId,
        'subjectName': subjectName,
        'topic': question.topic,
        'imagePath': question.imagePath,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding bookmark: $e');
      return false;
    }
  }

  Future<bool> removeBookmark(String questionId) async {
    try {
      if (_uid == null) return false;
      await _bookmarksRef!.doc(questionId).delete();
      return true;
    } catch (e) {
      debugPrint('Error removing bookmark: $e');
      return false;
    }
  }

  Future<bool> toggleBookmark(Question question, String subjectName) async {
    final isCurrentlyBookmarked = await isBookmarked(question.id);
    if (isCurrentlyBookmarked) {
      return await removeBookmark(question.id);
    } else {
      return await addBookmark(question, subjectName);
    }
  }

  Future<bool> isBookmarked(String questionId) async {
    try {
      if (_uid == null) return false;
      final doc = await _bookmarksRef!.doc(questionId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking bookmark: $e');
      return false;
    }
  }

  Future<List<BookmarkedQuestion>> getBookmarks() async {
    try {
      if (_uid == null) return [];
      final snapshot = await _bookmarksRef!
          .orderBy('bookmarkedAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        return BookmarkedQuestion.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching bookmarks: $e');
      return [];
    }
  }

  Stream<Set<String>> bookmarkedIdsStream() {
    if (_uid == null) return Stream.value({});
    return _bookmarksRef!
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toSet());
  }
}

class BookmarkedQuestion {
  final String id;
  final String text;
  final String? imagePath;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;
  final String subjectId;
  final String subjectName;
  final String? topic;
  final DateTime? savedAt;

  BookmarkedQuestion({
    required this.id,
    required this.text,
    this.imagePath,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
    required this.subjectId,
    required this.subjectName,
    this.topic,
    this.savedAt,
  });

  factory BookmarkedQuestion.fromFirestore(
      Map<String, dynamic> data, String id) {
    return BookmarkedQuestion(
      id: id,
      text: data['text'] ?? '',
      imagePath: data['imagePath'],
      options: List<String>.from(data['options'] ?? []),
      correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
      explanation: data['explanation'],
      subjectId: data['subjectId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      topic: data['topic'],
      // backwards compatible: handle both old 'savedAt' and new 'bookmarkedAt'
      savedAt: (data['bookmarkedAt'] as Timestamp?)?.toDate() ??
          (data['savedAt'] as Timestamp?)?.toDate(),
    );
  }

  Question toQuestion() {
    return Question(
      id: id,
      text: text,
      imagePath: imagePath,
      options: options,
      correctAnswerIndex: correctAnswerIndex,
      explanation: explanation,
      subjectId: subjectId,
      topic: topic,
    );
  }
}