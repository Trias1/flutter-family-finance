import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/biometric/app_lock.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/services/firebase_service.dart';
import 'package:family_finance_manager/core/services/currency_provider.dart';
import 'package:family_finance_manager/core/services/fcm_service.dart';
import 'package:family_finance_manager/core/services/notification_service.dart';
import 'package:family_finance_manager/core/services/widget_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/theme/theme_provider.dart';
import 'package:family_finance_manager/features/budget/presentation/providers/budget_provider.dart';
import 'package:family_finance_manager/routes/app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService().init();
  final title = message.notification?.title ?? 'Family Finance';
  final body = message.notification?.body ?? '';
  await NotificationService().show(id: DateTime.now().millisecondsSinceEpoch % 2147483647, title: title, body: body);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadInitialLocale();
  // Month/day names for the calendar and other intl formatting.
  await initializeDateFormatting();
  await FirebaseService.initialize();

  await NotificationService().init();
  WidgetService.initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FcmService().init();


  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Decided before the first frame so finance data never shows behind the lock.
  final startLocked = await fingerprintLockEnabled();

  runApp(
    ProviderScope(
      overrides: [
        appLockProvider.overrideWith((ref) => AppLockNotifier(startLocked)),
      ],
      child: const FamilyFinanceApp(),
    ),
  );
}

class FamilyFinanceApp extends ConsumerWidget {
  const FamilyFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(budgetAlertWatcherProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final locale = ref.watch(localeProvider);
    DateFormatter.languageCode = locale.languageCode;

    return MaterialApp.router(
      title: 'Family Finance',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme(themePreset),
      darkTheme: AppTheme.darkTheme(themePreset),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => AppLockGate(child: child!),
    );
  }
}
