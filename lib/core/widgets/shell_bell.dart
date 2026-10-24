import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/bank_inbox.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';
import 'package:family_finance_manager/features/bank_notifications/presentation/widgets/bank_inbox_banner.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';

/// Unpaid bills due within a week (or overdue).
List<BillModel> _dueSoon(WidgetRef ref) {
  final bills =
      ref.watch(dashboardProvider).valueOrNull?.upcomingBills ??
      const <BillModel>[];
  final limit = DateTime.now().add(const Duration(days: 7));
  return bills.where((b) => b.dueDate.isBefore(limit)).toList();
}

/// The bell next to ⋮: a count of things that need a look (bank
/// transactions to check, bills due within a week) and a panel listing them.
class ShellBell extends ConsumerWidget {
  const ShellBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final count = ref.watch(bankInboxProvider).length + _dueSoon(ref).length;
    return IconButton(
      tooltip: isId ? 'Notifikasi' : 'Notifications',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _NotificationsSheet(shellContext: context),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 9 ? '9+' : '$count'),
        backgroundColor: AppTheme.errorColor,
        child: Icon(
          count > 0
              ? Icons.notifications_rounded
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }
}

class _NotificationsSheet extends ConsumerWidget {
  /// Pages open from the shell, not from the sheet that is closing.
  final BuildContext shellContext;
  const _NotificationsSheet({required this.shellContext});

  String _due(BillModel b, bool isId) {
    final now = DateTime.now();
    final days = DateTime(
      b.dueDate.year,
      b.dueDate.month,
      b.dueDate.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return isId ? 'Lewat ${-days} hari' : '${-days} days overdue';
    if (days == 0) return isId ? 'Jatuh tempo hari ini' : 'Due today';
    if (days == 1) return isId ? 'Jatuh tempo besok' : 'Due tomorrow';
    return isId ? '$days hari lagi' : 'In $days days';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final waiting = ref.watch(bankInboxProvider);
    final bills = _dueSoon(ref);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              isId ? 'Notifikasi' : 'Notifications',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (waiting.isEmpty && bills.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Text(
                isId
                    ? 'Belum ada notifikasi. Semua beres.'
                    : 'Nothing new. All caught up.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          if (waiting.isNotEmpty)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: Text(
                isId
                    ? '${waiting.length} transaksi dari notifikasi bank'
                    : '${waiting.length} ${waiting.length == 1 ? 'transaction' : 'transactions'} from bank notifications',
              ),
              subtitle: Text(isId ? 'Menunggu dicek' : 'Waiting to be checked'),
              trailing: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  reviewBankInbox(shellContext, ref);
                },
                child: Text(isId ? 'Cek' : 'Check'),
              ),
            ),
          if (bills.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                isId ? 'Tagihan' : 'Bills',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final b in bills)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.warningColor.withValues(
                    alpha: 0.15,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.warningColor,
                  ),
                ),
                title: Text(b.name),
                subtitle: Text(_due(b, isId)),
                trailing: Text(
                  CurrencyFormatter.format(b.amount),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  shellContext.push('/bills');
                },
              ),
          ],
        ],
      ),
    );
  }
}
