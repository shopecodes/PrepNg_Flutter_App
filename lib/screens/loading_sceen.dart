// lib/screens/loading_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoadingScreen extends StatefulWidget {
  final VoidCallback onLoadingComplete;

  const LoadingScreen({
    super.key,
    required this.onLoadingComplete,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _tipController;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;

  int _currentTipIndex = 0;
  Timer? _tipTimer;
  final _random = Random();

  // Color palette matching onboarding
  static const Color _bgColor = Color(0xFFF5FAF6);
  static const Color _accentGreen = Color(0xFF4CAF7D);
  static const Color _darkGreen = Color(0xFF1A2E1F);

  final List<Map<String, String>> _allTips = [
    {'emoji': '🎯', 'tip': 'Small steps daily = Giant leaps in exams!'},
    {'emoji': '💡', 'tip': 'JAMB loves patterns - spot them, ace them!'},
    {'emoji': '📚', 'tip': 'Your future self will thank you for studying today'},
    {'emoji': '⚡', 'tip': 'Speed + Accuracy = JAMB Success Formula'},
    {'emoji': '🌟', 'tip': 'Every question answered is a step closer to your dream school'},
    {'emoji': '🔥', 'tip': 'Practice doesn\'t make perfect - Perfect practice does!'},
    {'emoji': '🎓', 'tip': 'Champions are made in practice, not in exams'},
    {'emoji': '💪', 'tip': 'You\'re not just preparing for exams - you\'re building excellence!'},
    {'emoji': '🚀', 'tip': 'Your admission letter is just questions away!'},
    {'emoji': '⏰', 'tip': '40 questions in 30 minutes? You\'re training for it right now!'},
  ];

  late List<Map<String, String>> _studyTips;

  @override
  void initState() {
    super.initState();

    _studyTips = List.from(_allTips)..shuffle(_random);

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _tipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _startTipRotation();
    });
  }

  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _studyTips.length;
        });
        _tipController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _tipController.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated Logo
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _logoFadeAnimation,
                    child: ScaleTransition(
                      scale: _logoScaleAnimation,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _accentGreen.withValues(alpha: 0.25),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/bookillustration3.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // App Name
              FadeTransition(
                opacity: _logoFadeAnimation,
                child: Text(
                  'PrepNG',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              FadeTransition(
                opacity: _logoFadeAnimation,
                child: Text(
                  'JAMB · WAEC',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Animated Study Tip
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder:
                    (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey<int>(_currentTipIndex),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _accentGreen.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentGreen.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _studyTips[_currentTipIndex]['emoji']!,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _studyTips[_currentTipIndex]['tip']!,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _darkGreen,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Loading indicator
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(_accentGreen),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Preparing your success journey...',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}