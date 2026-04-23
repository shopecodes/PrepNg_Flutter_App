// lib/screens/bookmarks/bookmarks_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bookmark_service.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with SingleTickerProviderStateMixin {

  final BookmarkService _bookmarkService = BookmarkService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<BookmarkedQuestion> _bookmarks = [];
  bool _isLoading = true;

  static const Color _accentGreen = Color(0xFF4CAF7D);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _loadBookmarks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    final bookmarks = await _bookmarkService.getBookmarks();
    if (mounted) {
      setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  Future<void> _removeBookmark(BookmarkedQuestion question) async {
    await _bookmarkService.removeBookmark(question.id);
    setState(() => _bookmarks.removeWhere((b) => b.id == question.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bookmark removed',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoader()
                : _bookmarks.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookmarks',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_bookmarks.length} saved question${_bookmarks.length == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────
  Widget _buildLoader() {
    return Center(
      child: CircularProgressIndicator(
        color: _accentGreen,
        strokeWidth: 3,
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────
  Widget _buildEmpty() {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final subtextColor = textColor.withValues(alpha: 0.6);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
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
                  Icons.bookmark_border_rounded,
                  size: 42,
                  color: _accentGreen.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No bookmarks yet',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tap the bookmark icon while\npractising to save questions here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: subtextColor,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bookmark List ──────────────────────────────────────────────
  Widget _buildList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        color: _accentGreen,
        onRefresh: _loadBookmarks,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: _bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = _bookmarks[index];
            return _BookmarkCard(
              bookmark: bookmark,
              index: index,
              onRemove: () => _removeBookmark(bookmark),
            );
          },
        ),
      ),
    );
  }
}

// ── Bookmark Card ──────────────────────────────────────────────────────────────
class _BookmarkCard extends StatefulWidget {
  final BookmarkedQuestion bookmark;
  final int index;
  final VoidCallback onRemove;

  const _BookmarkCard({
    required this.bookmark,
    required this.index,
    required this.onRemove,
  });

  @override
  State<_BookmarkCard> createState() => _BookmarkCardState();
}

class _BookmarkCardState extends State<_BookmarkCard> {
  bool _expanded = false;
  int? _selectedOption;

  static const Color _accentGreen = Color(0xFF4CAF7D);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var textColor = theme.colorScheme.onSurface;
    final subtextColor = textColor.withValues(alpha: 0.6);
    final b = widget.bookmark;
    final correctIndex = b.correctAnswerIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ───────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question number badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _accentGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subject pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accentGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            b.subjectName,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _accentGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b.text,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            height: 1.4,
                          ),
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand/collapse chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: subtextColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded: Options + Answer + Explanation ──────────
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Options
                  ...List.generate(b.options.length, (i) {
                    final isCorrect = i == correctIndex;
                    final isSelected = i == _selectedOption;
                    final showResult = _selectedOption != null;

                    Color borderColor = theme.dividerColor;
                    Color bgColor = theme.cardColor;
                    Color optionTextColor = textColor;
                    IconData? trailingIcon;
                    Color? iconColor;

                    if (showResult) {
                      if (isCorrect) {
                        borderColor = _accentGreen;
                        bgColor = _accentGreen.withValues(alpha: 0.08);
                        optionTextColor = textColor;
                        trailingIcon = Icons.check_circle_rounded;
                        iconColor = _accentGreen;
                      } else if (isSelected && !isCorrect) {
                        borderColor = Colors.red.shade300;
                        bgColor = Colors.red.shade50;
                        textColor = Colors.red.shade700;
                        trailingIcon = Icons.cancel_rounded;
                        iconColor = Colors.red.shade400;
                      }
                    }

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedOption = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isCorrect && showResult
                                    ? _accentGreen
                                    : isSelected && showResult
                                        ? Colors.red.shade400
                                        : theme.dividerColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(
                                      'A'.codeUnitAt(0) + i),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: showResult &&
                                            (isCorrect || isSelected)
                                        ? Colors.white
                                        : subtextColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                b.options[i],
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: optionTextColor,
                                  fontWeight: isCorrect && showResult
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (trailingIcon != null)
                              Icon(trailingIcon,
                                  color: iconColor, size: 18),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Explanation
                  if (b.explanation != null &&
                      b.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A86FF).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              const Color(0xFF3A86FF).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              color: const Color(0xFF3A86FF), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              b.explanation!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF1A5CCC),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Remove bookmark button
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.shade100, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_remove_rounded,
                              color: Colors.red.shade400, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Remove bookmark',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}
