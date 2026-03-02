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

class _ProgressHistoryScreenState extends State<ProgressHistoryScreen> {
  final ProgressService _progressService = ProgressService();

  @override
  void initState() {
    super.initState();
    debugPrint('=== LOADING HISTORY ===');
    debugPrint('User ID: ${FirebaseAuth.instance.currentUser?.uid}');
  }

  // Function to handle clear all history with confirmation
  Future<void> _showClearDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear All History?', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete all your quiz records. This cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );

      try {
        await _progressService.clearUserHistory();
        
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('History cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear history: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'My Progress',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            tooltip: 'Clear All History',
            onPressed: _showClearDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _progressService.getUserResults(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          // Error state
          if (snapshot.hasError) {
            debugPrint('=== HISTORY ERROR ===');
            debugPrint('Error: ${snapshot.error}');
            debugPrint('Error Type: ${snapshot.error.runtimeType}');
            debugPrint('====================');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading history',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {}); // Rebuild to retry
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Success state - display results with swipe-to-delete
          final results = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final doc = results[index];
              final data = doc.data() as Map<String, dynamic>;
              final documentId = doc.id;

              final score = data['score'] ?? 0;
              final total = data['totalQuestions'] ?? 1;
              final subject = data['subjectName'] ?? 'General Quiz';
              final double scorePercent = total > 0 ? (score / total) * 100 : 0;

              final DateTime date = data['timestamp'] != null
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now();

              // Wrap with Dismissible for swipe-to-delete
              return Dismissible(
                key: Key(documentId),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  // Show confirmation dialog before deleting
                  return await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Delete Quiz Result?',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      content: Text(
                        'Are you sure you want to delete this $subject quiz result? This cannot be undone.',
                        style: GoogleFonts.poppins(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ) ?? false;
                },
                onDismissed: (direction) async {
                  // Store context-dependent values before async operation
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  
                  try {
                    // Delete from Firestore
                    await FirebaseFirestore.instance
                        .collection('results')
                        .doc(documentId)
                        .delete();
                    
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('$subject quiz deleted'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: 'OK',
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    );
                  } catch (error) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      // Circular progress indicator
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: scorePercent / 100,
                              backgroundColor: Colors.grey.shade100,
                              color: scorePercent >= 50 
                                  ? Colors.green 
                                  : Colors.orange,
                              strokeWidth: 5,
                            ),
                            Text(
                              '${scorePercent.toInt()}%',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      
                      // Subject and date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Score
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$score/$total',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'Correct',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      
                      // Swipe indicator
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_back_ios,
                        size: 14,
                        color: Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_edu_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No quizzes completed yet',
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your progress summary will appear here.',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}