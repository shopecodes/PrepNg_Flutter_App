import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/progress_service.dart';

class ProgressHistoryScreen extends StatefulWidget {
  const ProgressHistoryScreen({super.key});

  @override
  State<ProgressHistoryScreen> createState() => _ProgressHistoryScreenState();
}

class _ProgressHistoryScreenState extends State<ProgressHistoryScreen>
    with SingleTickerProviderStateMixin {
  final ProgressService _progressService = ProgressService();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Color palette
  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  @override
  void initState() {
    super.initState();
    debugPrint('=== LOADING HISTORY ===');
    debugPrint('User ID: ${FirebaseAuth.instance.currentUser?.uid}');

    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _scoreColor(double percent) {
    if (percent >= 70) return _accentGreen;
    if (percent >= 50) return const Color(0xFFE89B4A);
    return Colors.red.shade400;
  }

  String _scoreLabel(double percent) {
    if (percent >= 70) return 'Great';
    if (percent >= 50) return 'Fair';
    return 'Retry';
  }

  Future<void> _showClearDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.delete_sweep_rounded,
                    color: Colors.red.shade600, size: 26),
              ),
              const SizedBox(height: 16),
              Text('Clear All History?',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkGreen)),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete all your quiz records. This cannot be undone.',
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
                      onTap: () => Navigator.pop(dialogContext, false),
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
                      onTap: () => Navigator.pop(dialogContext, true),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text('Delete All',
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

    if (confirm == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircularProgressIndicator(
                color: _accentGreen, strokeWidth: 2.5),
          ),
        ),
      );

      try {
        await _progressService.clearUserHistory();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('History cleared',
                  style: GoogleFonts.poppins(color: Colors.white)),
              backgroundColor: _accentGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear history: $e',
                  style: GoogleFonts.poppins(color: Colors.white)),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          // ── Gradient Header ──────────────────────────────────────
          Container(
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
                  color: _accentGreen.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Progress',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Your quiz history',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Clear all button
                    GestureDetector(
                      onTap: _showClearDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.delete_sweep_rounded,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Clear',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _progressService.getUserResults(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: _accentGreen, strokeWidth: 2.5),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.error_outline,
                                size: 40, color: Colors.red.shade400),
                          ),
                          const SizedBox(height: 20),
                          Text('Error loading history',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  color: _darkGreen)),
                          const SizedBox(height: 8),
                          Text(
                            'Please check your connection and try again',
                            style: GoogleFonts.poppins(
                                color: Colors.grey.shade500, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: () => setState(() {}),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color: _accentGreen,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        _accentGreen.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.refresh_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Retry',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final results = snapshot.data!.docs;

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final doc = results[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final documentId = doc.id;

                      final score = data['score'] ?? 0;
                      final total = data['totalQuestions'] ?? 1;
                      final subject =
                          data['subjectName'] ?? 'General Quiz';
                      final double scorePercent =
                          total > 0 ? (score / total) * 100 : 0;
                      final color = _scoreColor(scorePercent);
                      final label = _scoreLabel(scorePercent);

                      final DateTime date = data['timestamp'] != null
                          ? (data['timestamp'] as Timestamp).toDate()
                          : DateTime.now();

                      return Dismissible(
                        key: Key(documentId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(Icons.delete_outline,
                                  color: Colors.white, size: 22),
                              const SizedBox(width: 8),
                              Text('Delete',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => Dialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              backgroundColor: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.red.shade600,
                                          size: 26),
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Delete Result?',
                                        style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: _darkGreen)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Remove this $subject result? This cannot be undone.',
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
                                            onTap: () => Navigator.pop(
                                                dialogContext, false),
                                            child: Container(
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        14),
                                              ),
                                              child: Center(
                                                child: Text('Cancel',
                                                    style: GoogleFonts
                                                        .poppins(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                            color: Colors
                                                                .grey
                                                                .shade600)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => Navigator.pop(
                                                dialogContext, true),
                                            child: Container(
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade600,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        14),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.red
                                                        .withValues(
                                                            alpha: 0.3),
                                                    blurRadius: 12,
                                                    offset: const Offset(
                                                        0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Text('Delete',
                                                    style: GoogleFonts
                                                        .poppins(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            color: Colors
                                                                .white)),
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
                          ) ??
                              false;
                        },
                        onDismissed: (direction) async {
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          try {
                            await FirebaseFirestore.instance
                                .collection('results')
                                .doc(documentId)
                                .delete();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('$subject result deleted',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white)),
                                backgroundColor: _accentGreen,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } catch (error) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete: $error',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white)),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                            );
                          }
                        },

                        // ── Result Card ──────────────────────────
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Score ring
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: scorePercent / 100,
                                      backgroundColor:
                                          Colors.grey.shade100,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              color),
                                      strokeWidth: 5,
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${scorePercent.toInt()}%',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                            color: _darkGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 14),

                              // Subject + date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: _darkGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMM dd, yyyy • hh:mm a')
                                          .format(date),
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey.shade400,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // Score + label
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$score/$total',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: color,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      label,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_edu_rounded,
                  size: 52, color: _accentGreen.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'No quizzes yet',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete a quiz and your progress\nwill show up here.',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade400,
                fontSize: 13,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}