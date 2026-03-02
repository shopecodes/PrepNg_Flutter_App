import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prep_ng/screens/loading_sceen.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'provider/quiz_provider.dart';
import 'services/auth_services.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_check_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrepNg',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 1, 43, 2)),
        textTheme:
            GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
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
      // Record when initialization starts
      final startTime = DateTime.now();

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Enable offline persistence
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Wait for Firebase Auth to emit current user state
      final user = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      if (!mounted) return;

      // Determine next screen
      final nextScreen = user == null
          ? const LoginScreen()
          : const ProfileCheckWrapper();

      // Calculate how much time has passed since init started
      final elapsed = DateTime.now().difference(startTime);
      const minimumDuration = Duration(seconds: 5);

      // If init finished in less than 5 seconds, wait the remaining time
      // This guarantees loading screen always shows for exactly 5 seconds
      if (elapsed < minimumDuration) {
        await Future.delayed(minimumDuration - elapsed);
      }

      if (!mounted) return;

      setState(() {
        _nextScreen = nextScreen;
      });

      _navigateToNextScreen();
    } catch (e) {
      debugPrint('Error initializing app: $e');

      if (mounted) {
        setState(() {
          _nextScreen = const LoginScreen();
        });
        _navigateToNextScreen();
      }
    }
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