import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/budget/presentation/providers/budget_provider.dart';

class BudgetHistoryPage extends ConsumerWidget {
  const BudgetHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyId = ref.watch(financeScopeIdProvider);
    final historyAsync = ref.watch(budgetHistoryProvider(familyId));
    final isId = Localizations.localeOf(context).languageCode == 'id';

    // The app shell already shows the title and back arrow.
    return Scaffold(
      body: historyAsync.when(
        loading: () => const LoadingWidget(message: 'Memuat riwayat...'),
        error: (e, _) => AppErrorWidget(
          message: 'Gagal memuat riwayat: $e',
          onRetry: () => ref.invalidate(budgetHistoryProvider(familyId)),
        ),
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(isId ? 'Belum ada riwayat anggaran' : 'No budget history', style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            );
          }

          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final b in budgets) {
            final month = b.month;
            grouped.putIfAbsent(month, () => []);
            grouped[month]!.add({
              'category': b.category,
              'budgetAmount': b.budgetAmount,
              'usedAmount': b.usedAmount,
              'rolloverAmount': b.rolloverAmount,
              'remaining': b.budgetAmount - b.usedAmount,
            });
          }

          final sortedMonths = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: sortedMonths.length,
            itemBuilder: (context, index) {
              final month = sortedMonths[index];
              final items = grouped[month]!;
              final displayMonth = _formatMonth(month, isId);
              final totalRollover = items.fold<double>(0, (s, i) => s + (i['rolloverAmount'] as double));
              final isCurrentMonth = month == '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isCurrentMonth
                                ? '$displayMonth ${isId ? '(Bulan ini)' : '(Current)'}'
                                : displayMonth,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (totalRollover > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.incomeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${isId ? "Rollover" : "Rollover"}: ${CurrencyFormatter.format(totalRollover)}',
                                style: TextStyle(fontSize: 11, color: AppTheme.incomeColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...items.map((item) {
                        final cat = item['category'] as String;
                        final budget = item['budgetAmount'] as double;
                        final used = item['usedAmount'] as double;
                        final remaining = item['remaining'] as double;
                        final rollover = item['rolloverAmount'] as double;
                        final percentage = budget > 0 ? (used / budget).clamp(0.0, 1.0) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  Text(
                                    '${CurrencyFormatter.format(used)} / ${CurrencyFormatter.format(budget)}',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  used > budget ? AppTheme.errorColor : AppTheme.incomeColor,
                                ),
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${isId ? "Sisa" : "Left"}: ${CurrencyFormatter.format(remaining)}',
                                    style: TextStyle(fontSize: 11, color: remaining < 0 ? AppTheme.errorColor : AppTheme.incomeColor),
                                  ),
                                  if (rollover > 0)
                                    Text(
                                      '→ ${CurrencyFormatter.format(rollover)} ${isId ? "ke bln berikut" : "to next month"}',
                                      style: TextStyle(fontSize: 10, color: AppTheme.incomeColor),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatMonth(String month, bool isId) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final year = parts[0];
    final m = int.tryParse(parts[1]) ?? 1;
    if (isId) {
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${months[m]} $year';
    }
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[m]} $year';
  }
}
