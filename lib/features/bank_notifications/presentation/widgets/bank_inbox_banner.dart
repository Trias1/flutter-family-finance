import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/bank_inbox.dart';
import 'package:family_finance_manager/core/services/own_accounts.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/transactions/presentation/pages/statement_import_page.dart';

/// Opens the waiting transactions on the review screen; saved rows leave
/// the list. Used by the banner and by the "to check" notification.
Future<void> reviewBankInbox(BuildContext context, WidgetRef ref) async {
  final entries = ref.read(bankInboxProvider);
  if (entries.isEmpty) return;
  final ownNames = await ref
      .read(ownAccountNamesProvider.future)
      .catchError((_) => const <String>[]);
  if (!context.mounted) return;
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => StatementImportPage(
        items: [for (final e in entries) e.item],
        ownNames: ownNames,
        fromNotifications: true,
      ),
    ),
  );
  if (saved == true) {
    await ref
        .read(bankInboxProvider.notifier)
        .remove(entries.map((e) => e.source.id));
  }
}

/// "3 transactions from bank notifications are waiting": opens them on the
/// review screen; saved or skipped rows leave the list.
class BankInboxBanner extends ConsumerWidget {
  const BankInboxBanner({super.key});

  Future<void> _dismiss(
    BuildContext context,
    WidgetRef ref,
    List<BankInboxEntry> entries,
    bool isId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isId ? 'Abaikan semua?' : 'Skip them all?'),
        content: Text(
          isId
              ? '${entries.length} transaksi dari notifikasi bank dihapus dari daftar tunggu. Tidak ada yang dicatat.'
              : '${entries.length} transactions from bank notifications leave the waiting list. Nothing is recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isId ? 'Batal' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isId ? 'Abaikan' : 'Skip'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(bankInboxProvider.notifier)
          .remove(entries.map((e) => e.source.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(bankInboxProvider);
    if (entries.isEmpty) return const SizedBox.shrink();
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final color = AppTheme.primaryColor;
    final count = entries.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => reviewBankInbox(context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isId
                        ? '$count transaksi dari notifikasi bank menunggu dicek'
                        : '$count ${count == 1 ? 'transaction' : 'transactions'} from bank notifications to check',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
                TextButton(
                  onPressed: () => reviewBankInbox(context, ref),
                  child: Text(isId ? 'Cek' : 'Check'),
                ),
                IconButton(
                  tooltip: isId ? 'Abaikan semua' : 'Skip all',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => _dismiss(context, ref, entries, isId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
