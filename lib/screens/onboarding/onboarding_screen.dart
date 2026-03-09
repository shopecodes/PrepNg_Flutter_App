import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<OnboardingData> _pages = [
    OnboardingData(
      image: 'assets/images/Exams-bro.png',
      title: 'Study Smart.\nAce Exams.',
      subtitle:
          'Practice with 120+ questions per subject, all based on the official JAMB & WAEC syllabus.',
      bgColor: const Color(0xFFF5FAF6),
      accentColor: const Color(0xFF4CAF7D),
    ),
    OnboardingData(
      image: 'assets/images/disabled student-bro.png',
      title: 'Learn Anywhere.\nAnytime.',
      subtitle:
          'Offline support means you can practice even without internet. Your progress is always saved.',
      bgColor: const Color(0xFFF0F9F4),
      accentColor: const Color(0xFF388E5E),
    ),
    OnboardingData(
      image: 'assets/images/girl on graduation-bro.png',
      title: 'Your Success.\nOur Mission.',
      subtitle:
          'Join thousands of Nigerian students preparing smarter for their dream university.',
      bgColor: const Color(0xFFEBF7F0),
      accentColor: const Color(0xFF2E7D52),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _fadeController.reset();
    _slideController.reset();
    _fadeController.forward();
    _slideController.forward();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: page.bgColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        color: page.bgColor,
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 24),
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], size);
                  },
                ),
              ),

              // Bottom section
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                child: Column(
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? page.accentColor
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Next / Get Started button
                    GestureDetector(
                      onTap: _nextPage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          color: page.accentColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: page.accentColor.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingData data, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              height: size.height * 0.38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
              ),
              child: Image.asset(
                data.image,
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                data.title,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A2E1F),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                data.subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String image;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color accentColor;

  OnboardingData({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.accentColor,
  });
}