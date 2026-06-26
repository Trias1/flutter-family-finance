import 'package:flutter/material.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

final themePresetProvider = StateNotifierProvider<ThemePresetNotifier, AppThemePreset>((ref) {
  return ThemePresetNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('darkMode') ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', newMode == ThemeMode.dark);
  }
}

class ThemePresetNotifier extends StateNotifier<AppThemePreset> {
  ThemePresetNotifier() : super(AppTheme.defaultPreset) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppTheme.presetById(prefs.getString('themePreset'));
  }

  Future<void> setPreset(AppThemePreset preset) async {
    state = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themePreset', preset.id);
  }
}
