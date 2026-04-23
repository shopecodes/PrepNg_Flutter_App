// lib/screens/mock_exam/mock_subject_selection_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/question_model.dart';
import '../../services/connectivity_service.dart';
import 'mock_quiz_screen.dart';

class MockSubjectSelectionScreen extends StatefulWidget {
  const MockSubjectSelectionScreen({super.key});

  @override
  State<MockSubjectSelectionScreen> createState() =>
      _MockSubjectSelectionScreenState();
}

class _MockSubjectSelectionScreenState
    extends State<MockSubjectSelectionScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  bool _isStarting = false;
  String? _errorMessage;

  // All JAMB subjects (excluding Use-of-English)
  List<Map<String, dynamic>> _allSubjects = [];
  // IDs the user has unlocked
  Set<String> _unlockedIds = {};
  // IDs the user has selected for the mock exam
  final Set<String> _selectedSubjectIds = {};

  String? _useOfEnglishSubjectId;
  String? _useOfEnglishName;

  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const int _requiredAdditionalSubjects = 3;

  // ✅ Use of English: 60 questions (JAMB spec); all other subjects: 40
  static const int _questionsForUseOfEnglish = 60;
  static const int _questionsPerOtherSubject = 40;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadSubjects();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Cache-first Firestore query — instant from cache, falls back to
  /// server with 30s timeout on cache miss.
  Future<QuerySnapshot<Map<String, dynamic>>> _queryCollection(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      final cached =
          await query.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) {
        debugPrint('📦 Cache hit for query');
        return cached;
      }
    } catch (_) {}

    debugPrint('🌐 Cache miss — fetching from server');
    return await query
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw TimeoutException('Loading subjects timed out'),
        );
  }

  /// Cache-first single document fetch.
  Future<DocumentSnapshot<Map<String, dynamic>>> _getDoc(
      String collection, String docId) async {
    try {
      final cached = await _firestore
          .collection(collection)
          .doc(docId)
          .get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached;
    } catch (_) {}

    return await _firestore
        .collection(collection)
        .doc(docId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 30));
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ── Find Use-of-English via isFree:true ──────────────────────────────
      final freeSnap = await _queryCollection(
        _firestore
            .collection('subjects')
            .where('isFree', isEqualTo: true)
            .limit(1),
      );

      if (freeSnap.docs.isEmpty) {
        setState(() {
          _errorMessage = 'Could not find free subject. Check Firestore.';
          _isLoading = false;
        });
        return;
      }

      final freeDoc = freeSnap.docs.first;
      final jambScopeId = freeDoc.data()['scopeId'] as String? ?? '';
      _useOfEnglishSubjectId = freeDoc.id;
      _useOfEnglishName =
          freeDoc.data()['name'] as String? ?? 'Use-of-English';

      if (jambScopeId.isEmpty) {
        setState(() {
          _errorMessage = 'Free subject has no scopeId. Check Firestore.';
          _isLoading = false;
        });
        return;
      }

      // ── Fetch ALL subjects in JAMB scope ─────────────────────────────────
      final subjectsSnap = await _queryCollection(
        _firestore
            .collection('subjects')
            .where('scopeId', isEqualTo: jambScopeId),
      );

      // ── Get user's unlocked subject IDs ──────────────────────────────────
      final uid = _auth.currentUser?.uid;
      Set<String> unlockedIds = {};
      if (uid != null) {
        final userSubjectsSnap = await _queryCollection(
          _firestore
              .collection('user_subjects')
              .where('userId', isEqualTo: uid),
        );
        unlockedIds = userSubjectsSnap.docs
            .map((d) => d.data()['subjectId'] as String)
            .toSet();
      }

      // ── Build full subject list (exclude Use-of-English) ─────────────────
      // All subjects are shown. Unlocked ones are selectable, locked ones
      // show a lock icon and cannot be selected.
      final allSubjects = subjectsSnap.docs
          .where((doc) => doc.id != _useOfEnglishSubjectId)
          .map((doc) => {
                'id': doc.id,
                'name': doc.data()['name'] as String? ?? '',
                'icon': doc.data()['icon'] as String? ?? '📚',
              })
          .toList();

      allSubjects.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _allSubjects = allSubjects;
          _unlockedIds = unlockedIds;
          _isLoading = false;
        });
        _animController.forward();
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Loading timed out. Please check your internet and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subjects: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load subjects. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSubject(String subjectId) {
    if (_isStarting) return;
    // Only allow toggling unlocked subjects
    if (!_unlockedIds.contains(subjectId)) return;
    setState(() {
      if (_selectedSubjectIds.contains(subjectId)) {
        _selectedSubjectIds.remove(subjectId);
      } else if (_selectedSubjectIds.length < _requiredAdditionalSubjects) {
        _selectedSubjectIds.add(subjectId);
      }
    });
  }

  bool get _canStart =>
      _selectedSubjectIds.length == _requiredAdditionalSubjects;

  bool _timedOut = false;

  Future<void> _startMockExam() async {
    if (!_canStart || _isStarting || _useOfEnglishSubjectId == null) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _timedOut = false;
    setState(() => _isStarting = true);

    try {
      await _runStartMockExam(uid).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _timedOut = true;
          _showError('Connection timed out. Please check your internet.');
        },
      );
    } catch (e) {
      debugPrint('Error starting mock exam: $e');
      _timedOut = true;
      if (!e.toString().contains('timeout')) {
        _showError('Failed to start exam. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _runStartMockExam(String uid) async {
    try {
      final Map<String, List<Question>> subjectQuestions = {};
      final List<String> subjectNames = [];

      // ✅ Use of English always first — 60 questions
      final uoeQuestions = await _fetchQuestions(
        _useOfEnglishSubjectId!,
        uid,
        limit: _questionsForUseOfEnglish,
      );
      if (uoeQuestions == null) return;
      if (uoeQuestions.isEmpty) {
        _showError('No questions found for $_useOfEnglishName.');
        return;
      }
      subjectQuestions[_useOfEnglishName!] = uoeQuestions;
      subjectNames.add(_useOfEnglishName!);

      // ✅ Selected subjects — 40 questions each
      for (final subjectId in _selectedSubjectIds) {
        final subjectDoc = await _getDoc('subjects', subjectId);
        if (!subjectDoc.exists) return;

        final subjectName =
            subjectDoc.data()?['name'] as String? ?? subjectId;

        final questions = await _fetchQuestions(
          subjectId,
          uid,
          limit: _questionsPerOtherSubject,
        );
        if (questions == null) return;
        if (questions.isEmpty) {
          _showError('No questions found for $subjectName.');
          return;
        }

        subjectQuestions[subjectName] = questions;
        subjectNames.add(subjectName);
      }

      if (mounted && !_timedOut) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MockQuizScreen(
              subjectQuestions: subjectQuestions,
              subjects: subjectNames,
              selectedSubjectIds: [
                _useOfEnglishSubjectId!,
                ..._selectedSubjectIds,
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _runStartMockExam: $e');
      rethrow;
    }
  }

  // ✅ `limit` parameter — caller decides how many questions to take
  Future<List<Question>?> _fetchQuestions(
    String subjectId,
    String uid, {
    required int limit,
  }) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection('questions')
          .where('subjectId', isEqualTo: subjectId)
          .get(const GetOptions(source: Source.cache));

      if (snap.docs.isEmpty) throw Exception('Cache empty');
      debugPrint('📦 Questions from cache for $subjectId');
    } catch (_) {
      try {
        debugPrint('🌐 Fetching questions from server for $subjectId');
        snap = await _firestore
            .collection('questions')
            .where('subjectId', isEqualTo: subjectId)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        _showError('Connection timed out. Please check your internet.');
        return null;
      } catch (e) {
        _showError('Failed to load questions. Please try again.');
        return null;
      }
    }

    final all = snap.docs
        .map((d) => Question.fromFirestore(d.data(), d.id))
        .toList();

    if (all.isEmpty) return [];

    List<String> usedIds = [];
    try {
      final progressDoc = await _firestore
          .collection('quiz_progress')
          .doc(uid)
          .collection('mock_subjects')
          .doc(subjectId)
          .get();

      if (progressDoc.exists) {
        usedIds =
            List<String>.from(progressDoc.data()?['usedQuestionIds'] ?? []);
      }
    } catch (_) {}

    List<Question> pool =
        all.where((q) => !usedIds.contains(q.id)).toList();
    if (pool.length < limit) {
      pool = List.from(all);
      usedIds = [];
    }

    pool.shuffle();
    final selected = pool.take(limit).toList();

    try {
      await _firestore
          .collection('quiz_progress')
          .doc(uid)
          .collection('mock_subjects')
          .doc(subjectId)
          .set({
        'usedQuestionIds': [...usedIds, ...selected.map((q) => q.id)],
      });
    } catch (_) {}

    return selected;
  }

  void _showError(String msg) {
    connectivityScaffoldKey.currentState?.showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style:
                    GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: _accentGreen, strokeWidth: 2.5))
                : _errorMessage != null
                    ? _buildError(isDark: isDark)
                    : _buildBody(
                        isDark: isDark,
                        cardColor: cardColor,
                        textColor: textColor),
          ),
          if (!_isLoading && _errorMessage == null)
            _buildStartButton(isDark: isDark, cardColor: cardColor),
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
            color: _accentGreen.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JAMB Mock Exam',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Select $_requiredAdditionalSubjects subjects + Use of English',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '${_selectedSubjectIds.length}/$_requiredAdditionalSubjects subjects selected',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _selectedSubjectIds.length /
                            _requiredAdditionalSubjects,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white),
                        minHeight: 6,
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

  Widget _buildError({bool isDark = false}) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: textColor.withValues(alpha: 0.6),
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loadSubjects,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _accentGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Retry',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    bool isDark = false,
    Color cardColor = Colors.white,
    Color textColor = const Color(0xFF1A2E1F),
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        children: [
          _sectionLabel('Mandatory'),
          const SizedBox(height: 10),
          _subjectTile(
            name: _useOfEnglishName ?? 'Use-of-English',
            icon: '📖',
            isSelected: true,
            isUnlocked: true,
            isMandatory: true,
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          const SizedBox(height: 20),
          _sectionLabel('Choose $_requiredAdditionalSubjects subjects'),
          const SizedBox(height: 10),
          ..._allSubjects.map((subject) {
            final id = subject['id'] as String;
            final isUnlocked = _unlockedIds.contains(id);
            final isSelected = _selectedSubjectIds.contains(id);
            final isDisabled = _isStarting ||
                (!isSelected &&
                    _selectedSubjectIds.length >=
                        _requiredAdditionalSubjects);

            return _subjectTile(
              name: subject['name'] as String,
              icon: subject['icon'] as String? ?? '📚',
              isSelected: isSelected,
              isUnlocked: isUnlocked,
              isMandatory: false,
              isDisabled: isDisabled,
              onTap: isUnlocked ? () => _toggleSubject(id) : null,
              isDark: isDark,
              cardColor: cardColor,
              textColor: textColor,
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _accentGreen,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _subjectTile({
    required String name,
    required String icon,
    required bool isSelected,
    required bool isUnlocked,
    required bool isMandatory,
    bool isDisabled = false,
    VoidCallback? onTap,
    bool isDark = false,
    Color cardColor = Colors.white,
    Color textColor = const Color(0xFF1A2E1F),
  }) {
    final theme = Theme.of(context);
    final bool isLocked = !isUnlocked && !isMandatory;

    return GestureDetector(
      onTap: isLocked || isDisabled || isMandatory ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentGreen.withValues(alpha: 0.08)
              : isLocked
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : theme.dividerColor.withValues(alpha: 0.3))
                  : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _accentGreen.withValues(alpha: 0.5)
                : isLocked
                    ? theme.dividerColor.withValues(alpha: isDark ? 0.4 : 0.8)
                    : theme.dividerColor.withValues(alpha: isDark ? 0.4 : 0.8),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isLocked
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? _accentGreen.withValues(alpha: 0.1)
                    : isLocked
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : theme.dividerColor.withValues(alpha: 0.45))
                        : theme.dividerColor.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 20,
                    color: isLocked
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isLocked
                          ? (isDark
                              ? Colors.white30
                              : textColor.withValues(alpha: 0.45))
                          : isDisabled
                              ? (isDark
                                  ? Colors.white30
                                  : textColor.withValues(alpha: 0.45))
                              : textColor,
                    ),
                  ),
                  if (isLocked) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Unlock this subject to use in mock exam',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white24
                            : textColor.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right indicator
            if (isMandatory)
              Icon(Icons.lock_open_rounded,
                  color: _accentGreen, size: 18)
            else if (isLocked)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.orange.shade200, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 11, color: Colors.orange.shade700),
                    const SizedBox(width: 3),
                    Text('₦500',
                        style: GoogleFonts.poppins(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ],
                ),
              )
            else if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _accentGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: isDark
                          ? Colors.white24
                          : theme.dividerColor.withValues(alpha: 0.85),
                      width: 2),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton({
    bool isDark = false,
    Color cardColor = Colors.white,
  }) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: isDark ? 0.3 : 0.18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _canStart && !_isStarting ? _startMockExam : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: _canStart
                ? const LinearGradient(
                    colors: [Color(0xFF4CAF7D), Color(0xFF2E8B57)],
                  )
                : null,
            color: _canStart ? null : theme.dividerColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _canStart
                ? [
                    BoxShadow(
                      color: _accentGreen.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: _isStarting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: _canStart
                            ? Colors.white
                            : textColor.withValues(alpha: 0.6),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _canStart
                            ? 'Start Mock Exam'
                            : 'Select ${_requiredAdditionalSubjects - _selectedSubjectIds.length} more subject${(_requiredAdditionalSubjects - _selectedSubjectIds.length) == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: _canStart ? 16 : 13,
                          fontWeight: FontWeight.w700,
                          color: _canStart
                              ? Colors.white
                              : textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
