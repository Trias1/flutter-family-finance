import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Locale _initialLocale = const Locale('en', 'US');

Future<Locale> loadInitialLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString('locale') ?? 'en';
  _initialLocale = code == 'id' ? const Locale('id', 'ID') : const Locale('en', 'US');
  return _initialLocale;
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(_initialLocale);
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(super.initialLocale);

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
  }

  void toggle() {
    final next = state.languageCode == 'en' ? const Locale('id', 'ID') : const Locale('en', 'US');
    setLocale(next);
  }
}
