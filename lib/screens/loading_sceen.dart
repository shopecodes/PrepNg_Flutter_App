// lib/screens/loading_screen.dart

import 'dart:async';
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

  final List<Map<String, String>> _studyTips = [
    {
      'emoji': '🎯',
      'tip': 'Small steps daily = Giant leaps in exams!',
    },
    {
      'emoji': '💡',
      'tip': 'JAMB loves patterns - spot them, ace them!',
    },
    {
      'emoji': '📚',
      'tip': 'Your future self will thank you for studying today',
    },
    {
      'emoji': '⚡',
      'tip': 'Speed + Accuracy = JAMB Success Formula',
    },
    {
      'emoji': '🌟',
      'tip': 'Every question answered is a step closer to your dream school',
    },
    {
      'emoji': '🔥',
      'tip': 'Practice doesn\'t make perfect - Perfect practice does!',
    },
    {
      'emoji': '🎓',
      'tip': 'Champions are made in practice, not in exams',
    },
    {
      'emoji': '💪',
      'tip': 'You\'re not just preparing for exams - you\'re building excellence!',
    },
    {
      'emoji': '🚀',
      'tip': 'Your admission letter is just questions away!',
    },
    {
      'emoji': '⏰',
      'tip': '40 questions in 30 minutes? You\'re training for it right now!',
    },
  ];

  @override
  void initState() {
    super.initState();

    // Logo animates in over 1.5 seconds — fast and clean
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeIn,
      ),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    _tipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Start logo animation immediately
    _logoController.forward();

    // Start tip rotation after logo finishes
    Future.delayed(const Duration(milliseconds: 1500), () {
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/bookillustration1.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // App Name
              FadeTransition(
                opacity: _logoFadeAnimation,
                child: Text(
                  'PrepNG',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              FadeTransition(
                opacity: _logoFadeAnimation,
                child: Text(
                  'JAMB · WAEC',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    letterSpacing: 2,
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade50,
                        Colors.green.shade100.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 1,
                    ),
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
                          color: Colors.green.shade900,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Loading Indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.green.shade700),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Preparing your success journey...',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
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