// lib/screens/quiz/quiz_loading_screen.dart

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
  final int questionsPerQuiz;
  final int timeLimit;

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

class _QuizLoadingScreenState extends State<QuizLoadingScreen>
    with TickerProviderStateMixin {

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  List<Color> get _scopeGradient {
    final name = widget.scopeName.toUpperCase();
    if (name.contains('JAMB')) {
      return [const Color(0xFF4CAF7D), const Color(0xFF2E8B57)];
    } else if (name.contains('WAEC')) {
      return [const Color(0xFF3A86FF), const Color(0xFF1A5CCC)];
    }
    return [_accentGreen, _darkGreen];
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuestions();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    return '$minutes min';
  }

  Future<void> _loadQuestions() async {
    try {
      debugPrint('=== LOADING QUIZ ===');
      debugPrint('Subject: ${widget.subjectName}');
      debugPrint('Questions needed: ${widget.questionsPerQuiz}');

      final snapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('scopeId', isEqualTo: widget.scopeId)
          // ── FIXED: was Source.serverAndCache which returned stale cache ──
          .get(const GetOptions(source: Source.server));

      if (snapshot.docs.isEmpty) {
        _handleEmptyQuestions();
        return;
      }

      debugPrint('Found ${snapshot.docs.length} questions from server');

      final questions = snapshot.docs
          .map((doc) => Question.fromFirestore(doc.data(), doc.id))
          .toList();

      if (questions.length < widget.questionsPerQuiz) {
        _showInsufficientQuestionsDialog(questions.length, questions);
        return;
      }

      if (mounted) {
        final quizProvider = Provider.of<QuizProvider>(context, listen: false);
        await quizProvider.startQuiz(
          questions,
          widget.questionsPerQuiz,
          widget.timeLimit,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  QuizScreen(subjectName: widget.subjectName),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading questions: $e');
      _handleError();
    }
  }

  void _handleEmptyQuestions() {
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No questions available for ${widget.subjectName} yet.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showInsufficientQuestionsDialog(
      int availableQuestions, List<Question> questions) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.info_outline_rounded,
                    color: Colors.orange.shade700, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Limited Questions',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.scopeName} needs ${widget.questionsPerQuiz} questions, but only $availableQuestions are available for ${widget.subjectName}.\n\nWould you like to practice with what\'s available?',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        if (mounted) {
                          final quizProvider = Provider.of<QuizProvider>(
                              context,
                              listen: false);
                          await quizProvider.startQuiz(
                            questions,
                            availableQuestions,
                            widget.timeLimit,
                          );
                          navigator.pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => QuizScreen(
                                  subjectName: widget.subjectName),
                            ),
                          );
                        }
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _accentGreen,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _accentGreen.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text('Continue',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleError() {
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load quiz. Please check your connection.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _scopeGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: _scopeGradient[0].withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: -10,
                          right: -10,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.quiz_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                Text(
                  widget.subjectName,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'Getting your exam ready...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _infoChip(
                      icon: Icons.school_rounded,
                      label: widget.scopeName,
                    ),
                    const SizedBox(width: 10),
                    _infoChip(
                      icon: Icons.help_outline_rounded,
                      label: '${widget.questionsPerQuiz} Qs',
                    ),
                    const SizedBox(width: 10),
                    _infoChip(
                      icon: Icons.timer_outlined,
                      label: _formatTime(widget.timeLimit),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                Column(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _scopeGradient[0]),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Fetching questions from database...',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _accentGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _darkGreen,
            ),
          ),
        ],
      ),
    );
  }
}