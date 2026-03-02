import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/question_model.dart';
import '../../provider/quiz_provider.dart';
import 'quiz_screen.dart'; 

class QuizLoadingScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String scopeId;
  final String scopeName;
  final int questionsPerQuiz; // Dynamic question count (40 for JAMB, 60 for WAEC)
  final int timeLimit; // Dynamic time limit in seconds

  const QuizLoadingScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.scopeId,
    required this.scopeName,
    required this.questionsPerQuiz,
    required this.timeLimit,
  });

  @override
  State<QuizLoadingScreen> createState() => _QuizLoadingScreenState();
}

class _QuizLoadingScreenState extends State<QuizLoadingScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuestions();
    });
  }

  Future<void> _loadQuestions() async {
    try {
      debugPrint('=== LOADING QUIZ ===');
      debugPrint('Subject: ${widget.subjectName}');
      debugPrint('Scope: ${widget.scopeName}');
      debugPrint('Questions needed: ${widget.questionsPerQuiz}');
      debugPrint('Time limit: ${widget.timeLimit} seconds');
      
      // Fetch questions for this specific subject and scope
      final snapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('scopeId', isEqualTo: widget.scopeId)
          .get(const GetOptions(source: Source.serverAndCache));

      if (snapshot.docs.isEmpty) {
        _handleEmptyQuestions();
        return;
      }

      debugPrint('Found ${snapshot.docs.length} questions in database');

      // Map to Question objects
      List<Question> questions = snapshot.docs.map((doc) {
        return Question.fromFirestore(doc.data(), doc.id);
      }).toList();

      // Check if we have enough questions
      if (questions.length < widget.questionsPerQuiz) {
        _showInsufficientQuestionsDialog(questions.length, questions);
        return;
      }

      if (mounted) {
        final quizProvider = Provider.of<QuizProvider>(context, listen: false);
        
        // Pass all questions and let the provider shuffle and select
        quizProvider.startQuiz(
          questions, 
          widget.questionsPerQuiz,
          widget.timeLimit,
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              subjectName: widget.subjectName,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error loading questions: $e");
      _handleError();
    }
  }
  
  void _handleEmptyQuestions() {
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No questions available for ${widget.subjectName} yet.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showInsufficientQuestionsDialog(int availableQuestions, List<Question> questions) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Insufficient Questions', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This subject needs ${widget.questionsPerQuiz} questions for ${widget.scopeName}, but only $availableQuestions are available.\n\nDo you want to practice with the available questions?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to subject list
            },
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              
              if (mounted) {
                final quizProvider = Provider.of<QuizProvider>(context, listen: false);
                
                // Start quiz with available questions
                quizProvider.startQuiz(
                  questions,
                  availableQuestions,
                  widget.timeLimit,
                );
                
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(
                      subjectName: widget.subjectName,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _handleError() {
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load quiz. Please check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.green,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Preparing your ${widget.subjectName} Exam...',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.scopeName} • ${widget.questionsPerQuiz} Questions',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Time: ${_formatTime(widget.timeLimit)}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    return '$minutes minutes';
  }
}