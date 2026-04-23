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

class _SubjectListScreenState extends State<SubjectListScreen>
    with SingleTickerProviderStateMixin {
  final PurchaseService _purchaseService = PurchaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  Set<String> _unlockedSubjectIds = {};
  bool _isLoadingAccess = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  static const Color _accentGreen = Color(0xFF4CAF7D);

  Map<String, List<Color>> get _scopeGradient => {
        'JAMB': [const Color(0xFF4CAF7D), const Color(0xFF2E8B57)],
        'WAEC': [const Color(0xFF3A86FF), const Color(0xFF1A5CCC)],
      };

  List<Color> get _headerGradient {
    for (final key in _scopeGradient.keys) {
      if (widget.scopeName.toUpperCase().contains(key)) {
        return _scopeGradient[key]!;
      }
    }
    return [_accentGreen, const Color(0xFF1A2E1F)];
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Recovery is now handled in main.dart — do NOT call it here.
        // Just load access state. If main.dart's recovery just finished
        // writing to Firestore, _refreshAccess() will pick it up.
        _refreshAccess();
        _preFetchSubjects();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _preFetchSubjects() async {
    try {
      await FirebaseFirestore.instance
          .collection('subjects')
          .where('scopeId', isEqualTo: widget.scopeId)
          .get(const GetOptions(source: Source.serverAndCache));
    } catch (e) {
      debugPrint('Background pre-fetch failed: $e');
    }
  }

  Future<void> _refreshAccess() async {
    final ids = await _purchaseService.getPurchasedSubjectIds();
    if (mounted) {
      setState(() {
        _unlockedSubjectIds = ids;
        _isLoadingAccess = false;
      });
      _animController.forward();
    }
  }

  bool _isFreeSubject(Map<String, dynamic> data) => data['isFree'] == true;

  bool get _isJamb {
    final s = widget.scopeName.toLowerCase();
    return s.contains('jamb') || s.contains('utme');
  }

  bool get _isWaec {
    final s = widget.scopeName.toLowerCase();
    return s.contains('waec') || s.contains('wassce');
  }

  Map<String, dynamic> _getSubjectConfig(String subjectName) {
    if (_isJamb) {
      final isUseOfEnglish =
          subjectName.toLowerCase().contains('english');
      return isUseOfEnglish
          ? {'questionsPerQuiz': 60, 'timeLimit': 30 * 60}
          : {'questionsPerQuiz': 40, 'timeLimit': 20 * 60};
    }
    if (_isWaec) {
      return {'questionsPerQuiz': 60, 'timeLimit': 60 * 60};
    }
    return {'questionsPerQuiz': 50, 'timeLimit': 45 * 60};
  }

  void _showPaymentError(PaymentResult result) {
    if (!mounted) return;
    if (result.errorType == PaymentErrorType.cancelled) return;

    String message;
    IconData icon;
    Color color;
    int durationSeconds;

    switch (result.errorType) {
      case PaymentErrorType.network:
        message =
            'No internet connection. Please check your network and try again.';
        icon = Icons.wifi_off;
        color = Colors.orange;
        durationSeconds = 3;
        break;
      case PaymentErrorType.timeout:
        message =
            'Connection timed out. Please check your network and try again.';
        icon = Icons.timer_off;
        color = Colors.orange;
        durationSeconds = 3;
        break;
      case PaymentErrorType.server:
        message =
            result.errorMessage ?? 'Service unavailable. Try again later.';
        icon = Icons.cloud_off;
        color = Colors.red;
        durationSeconds = 4;
        break;
      case PaymentErrorType.verification:
        message = result.errorMessage ??
            'If you completed the bank transfer, your subject will unlock automatically the next time you open the app.';
        icon = Icons.info_outline_rounded;
        color = Colors.amber.shade700;
        durationSeconds = 6;
        break;
      default:
        message =
            result.errorMessage ?? 'An error occurred. Please try again.';
        icon = Icons.error_outline;
        color = Colors.red;
        durationSeconds = 4;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handlePurchaseTap(
      String subjectId, String subjectName) async {
    final hasInternet =
        await _connectivityService.hasInternetConnection();
    if (!mounted) return;
    if (!hasInternet) {
      SnackbarUtil.showNoInternetSnackbar(context);
      return;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.dialogTheme.backgroundColor ?? theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final subtextColor = textColor.withValues(alpha: 0.6);
    final fieldFill =
        theme.inputDecorationTheme.fillColor ?? theme.scaffoldBackgroundColor;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        backgroundColor: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.lock_open_rounded,
                    color: _accentGreen, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Unlock $subjectName',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Get full access to all practice questions for $subjectName for a one-time fee.',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: subtextColor,
                    height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: fieldFill,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        color: _accentGreen, size: 20),
                    const SizedBox(width: 10),
                    Text('One-time payment',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: subtextColor)),
                    const Spacer(),
                    Text('₦500',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textColor)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white12
                              : theme.dividerColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: subtextColor)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        final stillHasInternet = await _connectivityService
                            .hasInternetConnection();
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
                              child: Container(
                                margin: const EdgeInsets.all(40),
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius:
                                      BorderRadius.circular(24),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                        color: _accentGreen,
                                        strokeWidth: 2.5),
                                    const SizedBox(height: 16),
                                    Text('Processing payment...',
                                        style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: textColor)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        final result =
                            await _purchaseService.payAndUnlock(
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
                              content: Row(children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$subjectName is now unlocked!',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 13),
                                  ),
                                ),
                              ]),
                              backgroundColor: _accentGreen,
                              duration: const Duration(seconds: 3),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          );
                        } else {
                          _showPaymentError(result);
                        }
                      },
                      child: Container(
                        height: 48,
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
                        child: Center(
                          child: Text('Pay ₦500',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final subtextColor = textColor.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _headerGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: _headerGradient[0].withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.scopeName,
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text('Select a subject to begin',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white
                                      .withValues(alpha: 0.75))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoadingAccess
                ? Center(
                    child: CircularProgressIndicator(
                        color: _accentGreen, strokeWidth: 2.5))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('subjects')
                        .where('scopeId', isEqualTo: widget.scopeId)
                        .orderBy('order')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Error loading subjects!',
                                style: GoogleFonts.poppins(
                                    color: textColor)));
                      }
                      if (!snapshot.hasData) return const SizedBox();

                      final subjects = snapshot.data!.docs;

                      if (subjects.isEmpty) {
                        return Center(
                          child: Text(
                            'No subjects found for ${widget.scopeName}.',
                            style:
                                GoogleFonts.poppins(color: textColor),
                          ),
                        );
                      }

                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              20, 20, 20, 24),
                          itemCount: subjects.length,
                          itemBuilder: (context, index) {
                            final data = subjects[index].data()
                                as Map<String, dynamic>;
                            final id = subjects[index].id;
                            final subjectName =
                                data['name'] as String? ?? 'Subject';
                            final isFree = _isFreeSubject(data);
                            final hasAccess =
                                _unlockedSubjectIds.contains(id) ||
                                    isFree;

                            return GestureDetector(
                              onTap: () {
                                if (hasAccess) {
                                  final config =
                                      _getSubjectConfig(subjectName);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          QuizLoadingScreen(
                                        subjectId: id,
                                        subjectName: subjectName,
                                        scopeId: widget.scopeId,
                                        scopeName: widget.scopeName,
                                        questionsPerQuiz:
                                            config['questionsPerQuiz'],
                                        timeLimit: config['timeLimit'],
                                      ),
                                    ),
                                  );
                                } else {
                                  _handlePurchaseTap(id, subjectName);
                                }
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.shadowColor.withValues(
                                          alpha: isDark ? 0.26 : 0.16),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: hasAccess
                                            ? _accentGreen
                                                .withValues(alpha: 0.1)
                                            : (isDark
                                                ? theme.dividerColor
                                                    .withValues(alpha: 0.5)
                                                : theme.dividerColor
                                                    .withValues(alpha: 0.45)),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.menu_book_rounded,
                                        color: hasAccess
                                            ? _accentGreen
                                            : (isDark
                                                ? Colors.white54
                                                : subtextColor),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(subjectName,
                                              style: GoogleFonts.poppins(
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  fontSize: 15,
                                                  color: textColor)),
                                          const SizedBox(height: 3),
                                          Text(
                                              data['description'] ??
                                                  'Study pack available',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: subtextColor),
                                              maxLines: 1,
                                              overflow: TextOverflow
                                                  .ellipsis),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (hasAccess) ...[
                                      if (isFree)
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 10,
                                              vertical: 5),
                                          decoration: BoxDecoration(
                                            color: _accentGreen,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    20),
                                          ),
                                          child: Text('FREE',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  fontSize: 11,
                                                  letterSpacing: 0.5)),
                                        )
                                      else
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: _accentGreen
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    10),
                                          ),
                                          child: Icon(
                                              Icons.arrow_forward_rounded,
                                              color: _accentGreen,
                                              size: 16),
                                        ),
                                    ] else
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 12,
                                            vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors
                                                  .orange.shade200,
                                              width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_rounded,
                                                size: 12,
                                                color: Colors
                                                    .orange.shade700),
                                            const SizedBox(width: 4),
                                            Text('₦500',
                                                style:
                                                    GoogleFonts.poppins(
                                                        color: Colors
                                                            .orange
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight
                                                                .w700,
                                                        fontSize: 12)),
                                          ],
                                        ),
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
}
