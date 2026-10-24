import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/own_accounts.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

/// Settings row for the names on the user's bank accounts. Transfers to or
/// from these names (and family members) are moves between own accounts,
/// so imports do not count them as income or spending.
class OwnAccountsTile extends ConsumerWidget {
  const OwnAccountsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final names = ref.watch(ownAccountNamesProvider).valueOrNull ?? const [];
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _edit(context, ref, isId),
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
                  Icons.account_balance_outlined,
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
                      isId
                          ? 'Nama di rekening bank'
                          : 'Names on your bank accounts',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      names.isEmpty ? '-' : names.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
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

  Future<void> _edit(BuildContext context, WidgetRef ref, bool isId) async {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) return;
    final saved = await OwnAccounts.load(user.id);
    if (!context.mounted) return;
    final controller = TextEditingController(text: saved.join('\n'));
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isId ? 'Nama di rekening bank' : 'Names on your bank accounts',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isId
                    ? 'Tulis nama persis seperti di mutasi bank (biasanya nama lengkap sesuai KTP), satu nama per baris. Transfer ke/dari nama ini dianggap pindah antar rekening sendiri, jadi tidak dihitung pemasukan atau pengeluaran. Nama profil dan anggota keluarga sudah otomatis ikut.'
                    : 'Write the name exactly as on bank statements (usually your full legal name), one per line. Transfers to/from these names count as moving money between your own accounts. Your profile name and family members are included automatically.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'TRIAS ZAEN MUTAQIN',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isId ? 'Batal' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              controller.text
                  .split(RegExp(r'[\n,]'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
            ),
            child: Text(isId ? 'Simpan' : 'Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await OwnAccounts.save(user.id, result);
    ref.invalidate(ownAccountNamesProvider);
  }
}
