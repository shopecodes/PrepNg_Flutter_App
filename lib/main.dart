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
import 'services/purchase_service.dart';
import 'services/offline_service.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/profile_check_wrapper.dart';
import 'screens/question_of_the_day_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
}

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
      theme: ThemeProvider.lightTheme.copyWith(
        textTheme:
            GoogleFonts.poppinsTextTheme(ThemeProvider.lightTheme.textTheme),
      ),
      darkTheme: ThemeProvider.darkTheme.copyWith(
        textTheme:
            GoogleFonts.poppinsTextTheme(ThemeProvider.darkTheme.textTheme),
      ),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/qotd': (context) {
          final date =
              ModalRoute.of(context)?.settings.arguments as String?;
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
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final startTime = DateTime.now();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      Widget nextScreen = await _runInit().timeout(
        const Duration(seconds: 20),
        onTimeout: () => _onTimeout(),
      );

      final elapsed = DateTime.now().difference(startTime);
      const minimumDuration = Duration(seconds: 5);
      if (elapsed < minimumDuration) {
        await Future.delayed(minimumDuration - elapsed);
      }

      if (!mounted) return;
      _navigateTo(nextScreen);
    } catch (e) {
      debugPrint('Error initializing app: $e');
      if (mounted) _navigateTo(const WelcomeScreen());
    }
  }

  Future<Widget> _runInit() async {
    NotificationService.navigatorKey = navigatorKey;
    _initNotificationsSafely();

    // Flush any writes that were queued while the user was offline.
    // Fire-and-forget — never blocks startup.
    OfflineService.flushPendingWrites().catchError((e) {
      debugPrint('Error flushing pending writes: $e');
    });

    final User? user = FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 8), onTimeout: () => null);

    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    if (!onboardingComplete) return const OnboardingScreen();
    if (user == null) return const WelcomeScreen();

    _recoverPaymentInBackground();

    return const ProfileCheckWrapper();
  }

  void _recoverPaymentInBackground() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        debugPrint('🔍 Starting background payment recovery...');
        final result = await PurchaseService().recoverPendingPayment();

        if (result == null) {
          debugPrint('ℹ️ No recovery needed');
          return;
        }

        if (result.success) {
          debugPrint('✅ Recovery succeeded — showing success snackbar');
          _showSnackbar(
            message:
                'Your previous payment was confirmed and your subject is now unlocked! Go to your subject list to access it.',
            backgroundColor: const Color(0xFF4CAF7D),
            icon: Icons.check_circle_rounded,
            duration: const Duration(seconds: 6),
          );
        } else if (result.errorType == PaymentErrorType.incompleteReminder) {
          debugPrint('⚠️ Incomplete payment — showing reminder snackbar');
          _showSnackbar(
            message: result.errorMessage ??
                'You have an incomplete payment. If you\'ve already sent the money, your subject will unlock automatically. Otherwise tap a subject to complete your payment.',
            backgroundColor: Colors.amber.shade700,
            icon: Icons.info_outline_rounded,
            duration: const Duration(seconds: 7),
          );
        }
      } catch (e) {
        debugPrint('❌ Payment recovery error: $e');
      }
    });
  }

  void _showSnackbar({
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required Duration duration,
  }) {
    Future.delayed(const Duration(milliseconds: 500), () {
      connectivityScaffoldKey.currentState?.showSnackBar(
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
          backgroundColor: backgroundColor,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
  }

  void _initNotificationsSafely() {
    NotificationService()
        .initialize()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ NotificationService timed out');
          },
        )
        .catchError((e) {
      debugPrint('⚠️ NotificationService error: $e');
    });
  }

  Widget _onTimeout() {
    Future.delayed(const Duration(milliseconds: 600), () {
      connectivityScaffoldKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No internet connection. Please check your network.',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A2E1F),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
    return const WelcomeScreen();
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingScreen(
      onLoadingComplete: () {},
    );
  }
}