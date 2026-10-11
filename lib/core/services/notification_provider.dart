import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/services/bill_reminder_service.dart';

final notificationEnabledProvider =
    StateNotifierProvider<NotificationNotifier, bool>(
      (ref) => NotificationNotifier(),
    );

class NotificationNotifier extends StateNotifier<bool> {
  NotificationNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool('notifications_enabled', state);
    // Turning notifications off also drops reminders already scheduled;
    // turning them on re-schedules on the next bill update or app start.
    if (!state) await BillReminderService.sync(const [], isId: true);
  }
}
