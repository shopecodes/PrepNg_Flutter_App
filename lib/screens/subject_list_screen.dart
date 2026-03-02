import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prep_ng/screens/quiz/quiz_loading_screen.dart';
import '../services/purchase_service.dart';
import '../services/connectivity_service.dart';
import '../utils/snackbar_util.dart';

class SubjectListScreen extends StatefulWidget {
  final String scopeId;
  final String scopeName;

  const SubjectListScreen({
    super.key,
    required this.scopeId,
    required this.scopeName,
  });

  @override
  State<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends State<SubjectListScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  Set<String> _unlockedSubjectIds = {};
  bool _isLoadingAccess = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshAccess();
        _preFetchSubjects();
      }
    });
  }

  /// Silent background fetch to cache subjects for offline use
  Future<void> _preFetchSubjects() async {
    try {
      await FirebaseFirestore.instance
          .collection('subjects')
          .where('scopeId', isEqualTo: widget.scopeId)
          .get(const GetOptions(source: Source.serverAndCache));
      debugPrint('Offline cache updated for ${widget.scopeName}');
    } catch (e) {
      debugPrint('Background pre-fetch failed: $e');
    }
  }

  /// Refreshes the list of subjects the user has already paid for
  Future<void> _refreshAccess() async {
    final ids = await _purchaseService.getPurchasedSubjectIds();

    if (mounted) {
      setState(() {
        _unlockedSubjectIds = ids;
        _isLoadingAccess = false;
      });
    }
  }

  /// Check if a subject is free based on Firestore data
  bool _isFreeSubject(Map<String, dynamic> data) {
    return data['isFree'] == true;
  }

  /// Determine exam configuration based on scope name
  Map<String, dynamic> _getExamConfig() {
    final scopeNameLower = widget.scopeName.toLowerCase();

    if (scopeNameLower.contains('jamb') || scopeNameLower.contains('utme')) {
      return {
        'questionsPerQuiz': 40,
        'timeLimit': 30 * 60,
      };
    } else if (scopeNameLower.contains('waec') || scopeNameLower.contains('wassce')) {
      return {
        'questionsPerQuiz': 60,
        'timeLimit': 60 * 60,
      };
    } else if (scopeNameLower.contains('neco')) {
      return {
        'questionsPerQuiz': 60,
        'timeLimit': 60 * 60,
      };
    } else {
      return {
        'questionsPerQuiz': 50,
        'timeLimit': 45 * 60,
      };
    }
  }

  /// Show user-friendly error message based on payment error type
  void _showPaymentError(PaymentResult result) {
    if (!mounted) return;

    String message;
    IconData icon;
    Color color;

    switch (result.errorType) {
      case PaymentErrorType.network:
        message = result.errorMessage ?? 'Network connection issue. Please check your internet and try again.';
        icon = Icons.wifi_off;
        color = Colors.orange;
        break;

      case PaymentErrorType.cancelled:
        message = 'Payment was cancelled';
        icon = Icons.cancel_outlined;
        color = Colors.grey;
        break;

      case PaymentErrorType.timeout:
        message = 'Payment request timed out. Please try again.';
        icon = Icons.timer_off;
        color = Colors.orange;
        break;

      case PaymentErrorType.server:
        message = result.errorMessage ?? 'Payment service is temporarily unavailable. Please try again later.';
        icon = Icons.cloud_off;
        color = Colors.red;
        break;

      case PaymentErrorType.verification:
        message = result.errorMessage ?? 'Payment verification failed. Please check your transaction history.';
        icon = Icons.error_outline;
        color = Colors.amber;
        break;

      default:
        message = result.errorMessage ?? 'An error occurred. Please try again.';
        icon = Icons.error_outline;
        color = Colors.red;
    }

    if (result.errorType == PaymentErrorType.cancelled) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: result.errorType == PaymentErrorType.network ||
                result.errorType == PaymentErrorType.timeout
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: () {},
              )
            : null,
      ),
    );
  }

  /// Opens the payment dialog and triggers Paystack
  Future<void> _handlePurchaseTap(String subjectId, String subjectName) async {
    final hasInternet = await _connectivityService.hasInternetConnection();

    if (!mounted) return;

    if (!hasInternet) {
      SnackbarUtil.showNoInternetSnackbar(context);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Unlock $subjectName',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            'Get full access to all practice questions for $subjectName for ₦500.',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              final stillHasInternet = await _connectivityService.hasInternetConnection();

              if (!mounted) return;

              if (!stillHasInternet) {
                SnackbarUtil.showNoInternetSnackbar(context);
                return;
              }

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => PopScope(
                  canPop: false,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.green),
                            const SizedBox(height: 16),
                            Text('Processing payment...', style: GoogleFonts.poppins()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              final result = await _purchaseService.payAndUnlock(
                context,
                subjectId: subjectId,
                subjectName: subjectName,
              );

              if (!mounted) return;
              Navigator.of(context).pop();

              if (result.success) {
                await _refreshAccess();

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Payment successful! $subjectName is now unlocked.',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              } else {
                _showPaymentError(result);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Pay ₦500', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.scopeName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 54, 127, 57),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingAccess
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subjects')
                  .where('scopeId', isEqualTo: widget.scopeId)
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading subjects!', style: GoogleFonts.poppins()),
                  );
                }

                if (!snapshot.hasData) return const SizedBox();

                final subjects = snapshot.data!.docs;

                if (subjects.isEmpty) {
                  return Center(
                    child: Text('No subjects found for ${widget.scopeName}.',
                        style: GoogleFonts.poppins()),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final data = subjects[index].data() as Map<String, dynamic>;
                    final id = subjects[index].id;
                    final isFree = _isFreeSubject(data);
                    // Grant access if purchased OR if subject is free
                    final hasAccess = _unlockedSubjectIds.contains(id) || isFree;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor:
                              hasAccess ? Colors.green.shade50 : Colors.grey.shade100,
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: hasAccess
                                ? Colors.green.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                        title: Text(data['name'],
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        subtitle: Text(
                            data['description'] ?? 'Study pack available',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey.shade600)),
                        trailing: hasAccess
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Show FREE badge only if subject is free (not just purchased)
                                  if (isFree)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade700,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'FREE',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  if (isFree) const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      color: Colors.green, size: 18),
                                ],
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('₦500',
                                    style: GoogleFonts.poppins(
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    )),
                              ),
                        onTap: () {
                          if (hasAccess) {
                            final config = _getExamConfig();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuizLoadingScreen(
                                  subjectId: id,
                                  subjectName: data['name'],
                                  scopeId: widget.scopeId,
                                  scopeName: widget.scopeName,
                                  questionsPerQuiz: config['questionsPerQuiz'],
                                  timeLimit: config['timeLimit'],
                                ),
                              ),
                            );
                          } else {
                            _handlePurchaseTap(id, data['name']);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}