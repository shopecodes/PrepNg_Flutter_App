// lib/screens/quiz/result_screen.dart

import 'package:flutter/material.dart';
import '../../models/question_model.dart';
import '../../services/progress_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultScreen extends StatefulWidget {
  final String subjectName;
  final List<Question> questions;
  final Map<int, int> userAnswers;
  final int score;

  const ResultScreen({
    super.key,
    required this.subjectName,
    required this.questions,
    required this.userAnswers,
    required this.score,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ProgressService _progressService = ProgressService();
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _saveFinalResults();
  }

  // Automatically save results to Firestore
  Future<void> _saveFinalResults() async {
    try {
      await _progressService.saveQuizResult(
        subjectName: widget.subjectName,
        score: widget.score,
        totalQuestions: widget.questions.length,
      );
      if (mounted) {
        setState(() => _isSaved = true);
      }
    } catch (e) {
      debugPrint("Error saving results: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double percentage = (widget.score / widget.questions.length) * 100;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subjectName} Results', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        automaticallyImplyLeading: false, // Prevent going back to the quiz
      ),
      body: Column(
        children: [
          // Score Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(bottom: BorderSide(color: Colors.green.shade100)),
            ),
            child: Column(
              children: [
                Text('Your Score', style: GoogleFonts.poppins(fontSize: 16)),
                Text('${widget.score} / ${widget.questions.length}', 
                  style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                Text('${percentage.toStringAsFixed(1)}%', 
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                if (_isSaved)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_done, color: Colors.green, size: 16),
                      const SizedBox(width: 5),
                      Text("Progress Saved", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800)),
                    ],
                  ),
              ],
            ),
          ),
          
          // List of Review Questions
          Expanded(
            child: ListView.builder(
              itemCount: widget.questions.length,
              itemBuilder: (context, index) {
                final question = widget.questions[index];
                final userAnswer = widget.userAnswers[index];
                final isCorrect = userAnswer == question.correctAnswerIndex;

                return ExpansionTile(
                  leading: Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                  title: Text(question.text, style: GoogleFonts.poppins(fontSize: 14)),
                  subtitle: Text(isCorrect ? 'Correct' : 'Incorrect', 
                    style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Answer: ${userAnswer != null ? question.options[userAnswer] : "No Answer"}',
                              style: GoogleFonts.poppins(color: isCorrect ? Colors.green : Colors.red, fontSize: 13)),
                          Text('Correct Answer: ${question.options[question.correctAnswerIndex]}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (question.explanation != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text('Explanation: ${question.explanation}', 
                                style: GoogleFonts.poppins(color: Colors.blue.shade900, fontSize: 12, fontStyle: FontStyle.italic)),
                            ),
                          ]
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
          ),
          
          // Action Button
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Finish & Go Home', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}