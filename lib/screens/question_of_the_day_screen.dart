// lib/screens/qotd/question_of_the_day_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/question_model.dart';

class QuestionOfTheDayScreen extends StatefulWidget {
  final String? notificationDate;
  const QuestionOfTheDayScreen({super.key, this.notificationDate});

  @override
  State<QuestionOfTheDayScreen> createState() => _QuestionOfTheDayScreenState();
}

class _QuestionOfTheDayScreenState extends State<QuestionOfTheDayScreen>
    with SingleTickerProviderStateMixin {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Question? _question;
  int? _selectedIndex;
  bool _hasAnswered = false;
  bool _isLoading = true;
  // null = no QOTD scheduled for today, false = not answered, true = answered
  bool? _alreadyAnsweredToday;
  String? _noQuestionReason; // human-readable message for empty state

  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  // ── Date key used for Firestore lookups ──────────────────────
  // _resolvedDateKey is set after the doc is loaded so all reads
  // (question fetch, response check, response save) use the same date.
  String? _resolvedDateKey;

  String get _dateKey {
    // If already resolved (doc loaded), use that
    if (_resolvedDateKey != null) return _resolvedDateKey!;
    // If from notification, use that date
    final d = widget.notificationDate;
    if (d != null && d.isNotEmpty) return d;
    // Default to today
    final now = DateTime.now();
    final y = now.year.toString();
    final mo = now.month.toString().padLeft(2, '0');
    final dy = now.day.toString().padLeft(2, '0');
    return '$y-$mo-$dy';
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _loadQuestion();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── 1. Fetch QOTD document ────────────────────────────────
      // If opened from notification, use that date directly.
      // Otherwise, try today first — if no doc exists, fall back to
      // the most recent available question so the screen is never empty.
      DocumentSnapshot<Map<String, dynamic>>? qotdDoc;

      if (widget.notificationDate != null && widget.notificationDate!.isNotEmpty) {
        // Opened from notification — load exact date
        qotdDoc = await _firestore
            .collection('question_of_the_day')
            .doc(_dateKey)
            .get();
      } else {
        // Opened normally — try today first
        final todayDoc = await _firestore
            .collection('question_of_the_day')
            .doc(_dateKey)
            .get();

        if (todayDoc.exists) {
          qotdDoc = todayDoc;
        } else {
          // No doc for today yet — find the most recent available question
          // Fetch all docs and sort by ID client-side (IDs are YYYY-MM-DD strings
          // so lexicographic order = chronological order, no Firestore index needed)
          final allSnap = await _firestore
              .collection('question_of_the_day')
              .get();

          if (allSnap.docs.isNotEmpty) {
            allSnap.docs.sort((a, b) => b.id.compareTo(a.id));
            qotdDoc = allSnap.docs.first;
          }
        }
      }

      if (qotdDoc == null || !qotdDoc.exists) {
        if (mounted) {
          setState(() {
            _noQuestionReason = 'No question scheduled yet.\nCheck back soon!';
            _isLoading = false;
          });
        }
        return;
      }

      // Pin the date key to this doc's ID for all subsequent reads/writes
      _resolvedDateKey = qotdDoc.id;

      final qotdData = qotdDoc.data()!;

      // ── 2. Check if user already answered today ───────────────
      final responseDoc = await _firestore
          .collection('qotd_responses')
          .doc(_userId)
          .collection('responses')
          .doc(_dateKey)
          .get();

      final alreadyAnswered = responseDoc.exists;
      int? previousAnswer;
      if (alreadyAnswered) {
        previousAnswer = responseDoc.data()?['selectedIndex'] as int?;
      }

      // ── 3. Build Question from QOTD doc ──────────────────────
      // Handles 'question', 'text', or 'questionText' — whichever field name
      // the upload script used
      final questionText = (qotdData['question'] ??
              qotdData['text'] ??
              qotdData['questionText'] ??
              '') as String;

      if (questionText.isEmpty) {
        debugPrint(
            'QOTD doc exists but question text field missing. Fields: ${qotdData.keys.toList()}');
        if (mounted) {
          setState(() {
            _noQuestionReason =
                'Question data is incomplete. Please try again later.';
            _isLoading = false;
          });
        }
        return;
      }

      final question = Question(
        id: _dateKey,
        text: questionText,
        options: List<String>.from(qotdData['options'] ?? []),
        correctAnswerIndex: qotdData['correctAnswerIndex'] ?? 0,
        explanation: qotdData['explanation'],
        subjectId: qotdData['subject'] ?? '',
      );

      if (mounted) {
        setState(() {
          _question = question;
          _alreadyAnsweredToday = alreadyAnswered;
          if (alreadyAnswered) {
            _hasAnswered = true;
            _selectedIndex = previousAnswer;
          }
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error loading QOTD: $e');
      if (mounted) {
        setState(() {
          _noQuestionReason = 'Something went wrong. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectAnswer(int index) async {
    if (_hasAnswered || _userId == null) return;

    setState(() {
      _selectedIndex = index;
      _hasAnswered = true;
    });

    // ── Save response so it persists across sessions ──────────
    try {
      await _firestore
          .collection('qotd_responses')
          .doc(_userId)
          .collection('responses')
          .doc(_dateKey)
          .set({
        'userId': _userId,
        'date': _dateKey,
        'selectedIndex': index,
        'correct': index == _question!.correctAnswerIndex,
        'answeredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving QOTD response: $e');
    }
  }

  Color _optionColor(int index) {
    if (!_hasAnswered) {
      return _selectedIndex == index
          ? _accentGreen.withValues(alpha: 0.1)
          : Colors.white;
    }
    if (index == _question!.correctAnswerIndex) return Colors.green.shade50;
    if (index == _selectedIndex &&
        _selectedIndex != _question!.correctAnswerIndex) {
      return Colors.red.shade50;
    }
    return Colors.white;
  }

  Color _optionBorderColor(int index) {
    if (!_hasAnswered) {
      return _selectedIndex == index ? _accentGreen : Colors.grey.shade200;
    }
    if (index == _question!.correctAnswerIndex) return Colors.green.shade400;
    if (index == _selectedIndex &&
        _selectedIndex != _question!.correctAnswerIndex) {
      return Colors.red.shade400;
    }
    return Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: _accentGreen,
                      strokeWidth: 3,
                    ),
                  )
                : _question == null
                    ? _buildEmptyState()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF7D), Color(0xFF2E8B57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: _accentGreen.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question of the Day',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _dateKey,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 42,
                color: _accentGreen.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No question today',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _noQuestionReason ?? 'Check back tomorrow!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Already answered banner ───────────────────────
              if (_alreadyAnsweredToday == true) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _accentGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _accentGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: _accentGreen, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You've already answered today's question. Come back tomorrow!",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _darkGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Question card ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _accentGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Daily Challenge',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _accentGreen,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_question!.subjectId.isNotEmpty)
                          Text(
                            _question!.subjectId,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _question!.text,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _darkGreen,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Options ───────────────────────────────────────
              ...List.generate(
                _question!.options.length,
                (index) => _buildOption(index),
              ),

              // ── Explanation ───────────────────────────────────
              if (_hasAnswered && _question!.explanation != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Explanation',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _question!.explanation!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Result message ────────────────────────────────
              if (_hasAnswered) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _selectedIndex == _question!.correctAnswerIndex
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedIndex == _question!.correctAnswerIndex
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _selectedIndex == _question!.correctAnswerIndex
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedIndex == _question!.correctAnswerIndex
                              ? 'Correct! Great job! 🎉'
                              : 'Not quite. Keep practicing!',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color:
                                _selectedIndex == _question!.correctAnswerIndex
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(int index) {
    // Options are locked once answered
    final locked = _hasAnswered;

    return GestureDetector(
      onTap: locked ? null : () => _selectAnswer(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _optionColor(index),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _optionBorderColor(index),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _optionBorderColor(index).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _optionBorderColor(index),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _optionBorderColor(index),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _question!.options[index],
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _darkGreen,
                  height: 1.4,
                ),
              ),
            ),
            if (_hasAnswered && index == _question!.correctAnswerIndex)
              Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade600, size: 24),
            if (_hasAnswered &&
                index == _selectedIndex &&
                _selectedIndex != _question!.correctAnswerIndex)
              Icon(Icons.cancel_rounded,
                  color: Colors.red.shade600, size: 24),
          ],
        ),
      ),
    );
  }
}