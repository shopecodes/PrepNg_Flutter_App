import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _key = 'dark_mode';
  static const Color _brandGreen = Color(0xFF4CAF7D);
  static const Color _lightBackground = Color(0xFFF5FAF6);
  static const Color _lightSurface = Colors.white;
  static const Color _lightOnSurface = Color(0xFF1A2E1F);
  static const Color _darkBackground = Color(0xFF121817);
  static const Color _darkSurface = Color(0xFF1E2625);
  static const Color _darkFieldFill = Color(0xFF252E2C);

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDarkMode);
  }

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _lightBackground,
        surfaceColor: _lightSurface,
        onSurfaceColor: _lightOnSurface,
        fieldFillColor: _lightBackground,
        dividerColor: const Color(0xFFE3ECE6),
        shadowColor: Colors.black.withValues(alpha: 0.08),
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _darkBackground,
        surfaceColor: _darkSurface,
        onSurfaceColor: Colors.white,
        fieldFillColor: _darkFieldFill,
        dividerColor: Colors.white12,
        shadowColor: Colors.black.withValues(alpha: 0.3),
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackgroundColor,
    required Color surfaceColor,
    required Color onSurfaceColor,
    required Color fieldFillColor,
    required Color dividerColor,
    required Color shadowColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brandGreen,
      brightness: brightness,
      surface: surfaceColor,
      onSurface: onSurfaceColor,
    ).copyWith(
      primary: _brandGreen,
      error: const Color(0xFFC94B4B),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      cardColor: surfaceColor,
      dividerColor: dividerColor,
      shadowColor: shadowColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: onSurfaceColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brandGreen, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: onSurfaceColor.withValues(alpha: 0.45),
        ),
        labelStyle: TextStyle(
          color: onSurfaceColor.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}
