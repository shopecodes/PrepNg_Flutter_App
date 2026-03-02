import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // This is the method your ResultScreen is looking for!
  Future<void> saveQuizResult({
    required String subjectName,
    required int score,
    required int totalQuestions,
  }) async {
    final user = _auth.currentUser;
    
    // Only save if the user is logged in
    if (user != null) {
      await _db.collection('results').add({
        'userId': user.uid,
        'subjectName': subjectName,
        'score': score,
        'totalQuestions': totalQuestions,
        'timestamp': FieldValue.serverTimestamp(), // This sets the current time
      });
    }
  }

  // Used by the History screen to fetch data
  Stream<QuerySnapshot> getUserResults() {
    return _db
        .collection('results')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

// Add this inside your ProgressService class
Future<void> clearUserHistory() async {
  final user = _auth.currentUser;
  if (user == null) return;

  // Get all documents belonging to this user
  final snapshot = await _db
      .collection('results')
      .where('userId', isEqualTo: user.uid)
      .get();

  // Delete each document
  for (DocumentSnapshot doc in snapshot.docs) {
    await doc.reference.delete();
  }
}
}