import 'package:flutter/material.dart';

class AppThemePreset {
  final String id;
  final String name;
  final String vibe;
  final Color primary;
  final Color background;
  final Color accent;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.vibe,
    required this.primary,
    required this.background,
    required this.accent,
  });
}

class AppTheme {
  static const String fontFamily = 'PlusJakartaSans';

  static const List<AppThemePreset> presets = [
    AppThemePreset(
      id: 'mochaBrown',
      name: 'Mocha Brown',
      vibe: 'Hangat, keluarga, premium',
      primary: Color(0xFF6B3F2A),
      background: Color(0xFFFAF7F2),
      accent: Color(0xFFD97706),
    ),
    AppThemePreset(
      id: 'softPink',
      name: 'Soft Pink',
      vibe: 'Friendly, modern, nggak pinjol',
      primary: Color(0xFFBE185D),
      background: Color(0xFFFFF1F5),
      accent: Color(0xFFF59E0B),
    ),
    AppThemePreset(
      id: 'roseGold',
      name: 'Rose Gold',
      vibe: 'Elegan, feminine, premium',
      primary: Color(0xFF9F1239),
      background: Color(0xFFFFF7ED),
      accent: Color(0xFFD97706),
    ),
    AppThemePreset(
      id: 'oceanBlue',
      name: 'Ocean Blue',
      vibe: 'Trust, finance, bank-like',
      primary: Color(0xFF1D4ED8),
      background: Color(0xFFF8FAFC),
      accent: Color(0xFF06B6D4),
    ),
    AppThemePreset(
      id: 'lavender',
      name: 'Lavender',
      vibe: 'Soft, clean, lifestyle app',
      primary: Color(0xFF7C3AED),
      background: Color(0xFFF5F3FF),
      accent: Color(0xFFEC4899),
    ),
    AppThemePreset(
      id: 'charcoalGold',
      name: 'Charcoal Gold',
      vibe: 'Premium/dark, classy',
      primary: Color(0xFF111827),
      background: Color(0xFFF9FAFB),
      accent: Color(0xFFD97706),
    ),
    AppThemePreset(
      id: 'sage',
      name: 'Sage',
      vibe: 'Calm/natural, bukan hijau pinjol terang',
      primary: Color(0xFF64748B),
      background: Color(0xFFF8FAF5),
      accent: Color(0xFFA16207),
    ),
  ];

  static const AppThemePreset defaultPreset = AppThemePreset(
    id: 'mochaBrown',
    name: 'Mocha Brown',
    vibe: 'Hangat, keluarga, premium',
    primary: Color(0xFF6B3F2A),
    background: Color(0xFFFAF7F2),
    accent: Color(0xFFD97706),
  );

  static AppThemePreset presetById(String? id) {
    return presets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => defaultPreset,
    );
  }

  static AppThemePreset _activePreset = defaultPreset;

  static Color get primaryColor => _activePreset.primary;
  static Color get secondaryColor => _activePreset.accent;
  static Color get accentColor => _activePreset.accent;
  static const Color errorColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color incomeColor = Color(0xFF059669);
  static const Color expenseColor = Color(0xFFDC2626);
  static const Color savingsColor = Color(0xFF2563EB);

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
    displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
  );

  static ThemeData lightTheme([AppThemePreset preset = defaultPreset]) {
    _activePreset = preset;
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      textTheme: _textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: preset.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: preset.background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData darkTheme([AppThemePreset preset = defaultPreset]) {
    _activePreset = preset;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: preset.primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      textTheme: _textTheme,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: preset.primary.withValues(alpha: 0.12),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
