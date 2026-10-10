import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/services/notification_service.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';

/// Schedules local reminders for unpaid bills: the day before at 09:00 and
/// on the due day at 08:00. Runs on the phone, so it works offline and costs
/// nothing; it is re-run whenever the bill list changes.
class BillReminderService {
  static const _idsKey = 'bill_reminder_ids';

  // Keeps reminder ids apart from other notifications.
  static int _idFor(String billId, int slot) =>
      500000 + (billId.hashCode.abs() % 200000) * 2 + slot;

  static Future<void> sync(List<BillModel> bills, {required bool isId}) async {
    final prefs = await SharedPreferences.getInstance();
    final service = NotificationService();
    for (final id in prefs.getStringList(_idsKey) ?? const <String>[]) {
      await service.cancel(int.parse(id));
    }
    final scheduled = <String>[];
    if (prefs.getBool('notifications_enabled') ?? true) {
      final now = DateTime.now();
      for (final bill in bills) {
        if (bill.status == BillStatus.paid) continue;
        final due = bill.dueDate;
        final dayBefore = DateTime(due.year, due.month, due.day - 1, 9);
        final dueDay = DateTime(due.year, due.month, due.day, 8);
        final amount = CurrencyFormatter.format(bill.amount);
        if (dayBefore.isAfter(now)) {
          final id = _idFor(bill.id, 0);
          await service.schedule(
            id: id,
            title: isId ? 'Tagihan besok' : 'Bill due tomorrow',
            body: '${bill.name} · $amount',
            when: dayBefore,
          );
          scheduled.add('$id');
        }
        if (dueDay.isAfter(now)) {
          final id = _idFor(bill.id, 1);
          await service.schedule(
            id: id,
            title: isId ? 'Tagihan jatuh tempo hari ini' : 'Bill due today',
            body: '${bill.name} · $amount',
            when: dueDay,
          );
          scheduled.add('$id');
        }
      }
    }
    await prefs.setStringList(_idsKey, scheduled);
  }
}
