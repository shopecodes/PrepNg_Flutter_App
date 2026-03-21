import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prep_ng/screens/loading_sceen.dart';
import 'package:prep_ng/screens/onboarding/onboarding_screen.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'provider/quiz_provider.dart';
import 'provider/theme_provider.dart';
import 'services/auth_services.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/profile_check_wrapper.dart';
import 'screens/question_of_the_day_screen.dart';

// ── Background message handler (must be top-level) ──────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
}

// ── Global navigator key for notification navigation ────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'PrepNg',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: connectivityScaffoldKey,
      // Theme switches for logged-in screens; login/onboarding stay light
      theme: ThemeProvider.lightTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(ThemeProvider.lightTheme.textTheme),
      ),
      darkTheme: ThemeProvider.darkTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(ThemeProvider.darkTheme.textTheme),
      ),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/qotd': (context) {
          // Pass the date argument from the notification to the screen
          final date = ModalRoute.of(context)?.settings.arguments as String?;
          return QuestionOfTheDayScreen(notificationDate: date);
        },
      },
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final startTime = DateTime.now();

      // ── Step 1: Firebase core init — no internet needed, must always complete ──
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Enable offline persistence right after core init
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // ── Step 2: Network-dependent calls — capped at 20 seconds ──
      await _runInit().timeout(
        const Duration(seconds: 20),
        onTimeout: () => _handleTimeout(),
      );

      // Guarantee loading screen shows for at least 5 seconds
      final elapsed = DateTime.now().difference(startTime);
      const minimumDuration = Duration(seconds: 5);
      if (elapsed < minimumDuration) {
        await Future.delayed(minimumDuration - elapsed);
      }

      if (!mounted) return;
      _navigateToNextScreen();
    } catch (e) {
      debugPrint('Error initializing app: $e');
      if (mounted) {
        setState(() => _nextScreen = const WelcomeScreen());
        _navigateToNextScreen();
      }
    }
  }

  Future<void> _runInit() async {
    // Initialize notifications (needs Firebase to be ready)
    NotificationService.navigatorKey = navigatorKey;
    await NotificationService().initialize();

    // Auth check + onboarding check in parallel
    final results = await Future.wait([
      FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => null),
      SharedPreferences.getInstance(),
    ]);

    if (!mounted) return;

    final user = results[0] as User?;
    final prefs = results[1] as SharedPreferences;
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    setState(() {
      _nextScreen = !onboardingComplete
          ? const OnboardingScreen()
          : user == null
              ? const WelcomeScreen()
              : const ProfileCheckWrapper();
    });
  }

  void _handleTimeout() {
    // Fall through to login so app isn't stuck on loading screen
    if (mounted) {
      setState(() => _nextScreen = const WelcomeScreen());
    }

    // Show snackbar after navigation so it appears briefly then auto-dismisses
    Future.delayed(const Duration(milliseconds: 600), () {
      connectivityScaffoldKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No internet connection. Please check your network.',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A2E1F),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
  }

  void _navigateToNextScreen() {
    if (_nextScreen != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => _nextScreen!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingScreen(
      onLoadingComplete: _navigateToNextScreen,
    );
  }
}