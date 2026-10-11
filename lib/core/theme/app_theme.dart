import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppThemePreset {
  final String id;
  final String name;

  /// Short description shown under the preset name (Indonesian / English).
  final String vibe;
  final String vibeEn;
  final Color primary;
  final Color background;
  final Color accent;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.vibe,
    required this.vibeEn,
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
      vibe: 'Cokelat hangat, nyaman di mata',
      vibeEn: 'Warm brown, easy on the eyes',
      primary: Color(0xFF6B4430),
      background: Color(0xFFF8F5F0),
      accent: Color(0xFFA0763F),
    ),
    AppThemePreset(
      id: 'softPink',
      name: 'Soft Pink',
      vibe: 'Merah muda kalem',
      vibeEn: 'Muted pink',
      primary: Color(0xFF9C4F63),
      background: Color(0xFFF9F5F5),
      accent: Color(0xFFA3855A),
    ),
    AppThemePreset(
      id: 'roseGold',
      name: 'Rose Gold',
      vibe: 'Merah bata lembut',
      vibeEn: 'Soft brick red',
      primary: Color(0xFF8A4B45),
      background: Color(0xFFF9F5F2),
      accent: Color(0xFFAC8556),
    ),
    AppThemePreset(
      id: 'oceanBlue',
      name: 'Ocean Blue',
      vibe: 'Biru tenang, kesan rapi',
      vibeEn: 'Calm blue, tidy and clear',
      primary: Color(0xFF2B4C6F),
      background: Color(0xFFF6F6F4),
      accent: Color(0xFF8A7552),
    ),
    AppThemePreset(
      id: 'lavender',
      name: 'Lavender',
      vibe: 'Ungu redup',
      vibeEn: 'Dusky violet',
      primary: Color(0xFF5E5288),
      background: Color(0xFFF7F6F8),
      accent: Color(0xFF978157),
    ),
    AppThemePreset(
      id: 'charcoalGold',
      name: 'Charcoal Gold',
      vibe: 'Arang gelap dengan aksen emas',
      vibeEn: 'Charcoal with a brass accent',
      primary: Color(0xFF2A2D33),
      background: Color(0xFFF6F6F4),
      accent: Color(0xFF9A7E4C),
    ),
    AppThemePreset(
      id: 'sage',
      name: 'Sage',
      vibe: 'Hijau daun yang teduh',
      vibeEn: 'Soft leaf green',
      primary: Color(0xFF55704E),
      background: Color(0xFFF5F6F2),
      accent: Color(0xFF9C8253),
    ),
  ];

  static const AppThemePreset defaultPreset = AppThemePreset(
    id: 'mochaBrown',
    name: 'Mocha Brown',
    vibe: 'Cokelat hangat, nyaman di mata',
    vibeEn: 'Warm brown, easy on the eyes',
    primary: Color(0xFF6B4430),
    background: Color(0xFFF8F5F0),
    accent: Color(0xFFA0763F),
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
  static const Color errorColor = Color(0xFFA8443A);
  static const Color warningColor = Color(0xFF9A6417);
  static const Color incomeColor = Color(0xFF2F7354);
  static const Color expenseColor = Color(0xFFA8443A);
  static const Color savingsColor = Color(0xFF3D6189);

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

  /// Pages slide in from the right with the previous one easing aside, like
  /// Telegram, instead of Android's default zoom.
  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData lightTheme([AppThemePreset preset = defaultPreset]) {
    _activePreset = preset;
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      textTheme: _textTheme,
      pageTransitionsTheme: _pageTransitions,
      colorScheme: ColorScheme.fromSeed(
        seedColor: preset.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: preset.background,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
      pageTransitionsTheme: _pageTransitions,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
