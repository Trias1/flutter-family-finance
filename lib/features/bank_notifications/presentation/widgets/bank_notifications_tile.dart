import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/bank_inbox.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';

/// Settings row for reading bank notifications. Android only lets the user
/// grant Notification access in its own settings screen, so this explains
/// what is read and opens that screen.
class BankNotificationsTile extends ConsumerWidget {
  const BankNotificationsTile({super.key});

  Future<void> _explain(BuildContext context, bool isId, bool on) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isId ? 'Baca notifikasi bank' : 'Read bank notifications'),
        content: SingleChildScrollView(
          child: Text(
            isId
                ? 'Saat bank atau e-wallet mengirim notifikasi transaksi (uang masuk, transfer, bayar QRIS), aplikasi mencatatnya ke daftar "menunggu dicek" di Dashboard. Tidak ada yang tersimpan sebelum kamu cek dan simpan.\n\n'
                      'Yang dibaca hanya notifikasi yang menyebut nominal (Rp/IDR). Chat seperti WhatsApp dan Telegram diabaikan, kode OTP dan promo dibuang. Semua diproses di HP ini, tidak dikirim ke server.\n\n'
                      '${on ? 'Untuk mematikan, matikan Family Finance di layar Akses notifikasi.' : 'Di layar berikutnya, nyalakan Family Finance di Akses notifikasi.'}'
                : 'When a bank or e-wallet notifies you of a transaction (money in, transfer, QRIS payment), the app adds it to a "to check" list on the Dashboard. Nothing is recorded until you check and save it.\n\n'
                      'Only notifications that mention an amount (Rp/IDR) are read. Chats such as WhatsApp and Telegram are ignored; codes and promos are dropped. Everything stays on this phone.\n\n'
                      '${on ? 'To stop, turn Family Finance off on the Notification access screen.' : 'On the next screen, turn on Family Finance under Notification access.'}',
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isId ? 'Batal' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isId ? 'Buka pengaturan' : 'Open settings'),
          ),
        ],
      ),
    );
    if (open == true) await BankNotifications.openSettings();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref.watch(bankFeatureProvider).valueOrNull ?? false)) {
      return const SizedBox.shrink();
    }
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final on = ref.watch(bankAccessProvider).valueOrNull ?? false;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _explain(context, isId, on),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isId ? 'Baca notifikasi bank' : 'Read bank notifications',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      on
                          ? (isId
                                ? 'Aktif · transaksi masuk ke daftar menunggu dicek'
                                : 'On · transactions go to the to-check list')
                          : (isId ? 'Mati' : 'Off'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: on
                            ? AppTheme.incomeColor
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
