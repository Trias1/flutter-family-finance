import 'package:flutter/material.dart';
import 'package:family_finance_manager/core/services/prediction_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/debt_model.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/user_model.dart';

// Dashboard cards that turn existing data into answers: who spent what,
// where the money went, what is owed, and where the month is heading.

bool _isSavingsTransfer(String category) =>
    category == 'Tabungan' || category == 'Savings';

bool _inMonth(DateTime d, DateTime month) =>
    d.year == month.year && d.month == month.month;

/// Spending (not transfers to savings) in the month containing [month].
List<ExpenseModel> monthSpending(List<ExpenseModel> all, DateTime month) => all
    .where((e) => _inMonth(e.date, month) && !_isSavingsTransfer(e.category))
    .toList();

class _CardShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _CardShell({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final String label;
  final double amount;
  final double share;
  final Color color;
  final String? note;

  const _ShareRow({
    required this.label,
    required this.amount,
    required this.share,
    required this.color,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (note != null) ...[
                Text(note!, style: TextStyle(fontSize: 11, color: muted)),
                const SizedBox(width: 8),
              ],
              Text(
                CurrencyFormatter.format(amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0, 1).toDouble(),
              minHeight: 5,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Family mode: how this month's spending splits across members.
class MemberSpendingCard extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final List<UserModel> members;
  final bool isId;

  const MemberSpendingCard({
    super.key,
    required this.expenses,
    required this.members,
    required this.isId,
  });

  @override
  Widget build(BuildContext context) {
    final spending = monthSpending(expenses, DateTime.now());
    final total = spending.fold<double>(0, (s, e) => s + e.amount);
    final byUser = <String, double>{};
    for (final e in spending) {
      byUser[e.userId] = (byUser[e.userId] ?? 0) + e.amount;
    }
    final names = {for (final m in members) m.id: m.name};
    final rows = byUser.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _CardShell(
      icon: Icons.groups_rounded,
      title: isId ? 'Pengeluaran per anggota' : 'Spending by member',
      child: rows.isEmpty
          ? Text(
              isId
                  ? 'Belum ada pengeluaran bulan ini.'
                  : 'No spending this month yet.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (final r in rows)
                  _ShareRow(
                    label:
                        names[r.key] ?? (isId ? 'Mantan anggota' : 'Former member'),
                    amount: r.value,
                    share: total > 0 ? r.value / total : 0,
                    note: total > 0
                        ? '${(r.value / total * 100).round()}%'
                        : null,
                    color: AppTheme.primaryColor,
                  ),
              ],
            ),
    );
  }
}

/// Top categories this month with the change against last month.
class CategoryBreakdownCard extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final bool isId;

  const CategoryBreakdownCard({
    super.key,
    required this.expenses,
    required this.isId,
  });

  Map<String, double> _byCategory(List<ExpenseModel> list) {
    final map = <String, double>{};
    for (final e in list) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = monthSpending(expenses, now);
    final previous = monthSpending(expenses, DateTime(now.year, now.month - 1));
    final thisMonth = _byCategory(current);
    final lastMonth = _byCategory(previous);
    final total = thisMonth.values.fold<double>(0, (s, v) => s + v);
    final lastTotal = lastMonth.values.fold<double>(0, (s, v) => s + v);
    final rows = thisMonth.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    String? change(double now, double before) {
      if (before <= 0) return null;
      final pct = ((now - before) / before * 100).round();
      if (pct == 0) return '±0%';
      return pct > 0 ? '+$pct%' : '$pct%';
    }

    return _CardShell(
      icon: Icons.donut_small_rounded,
      title: isId ? 'Ke mana uang bulan ini' : 'Where the money went',
      trailing: lastTotal > 0
          ? Text(
              '${isId ? 'vs bulan lalu' : 'vs last month'} ${change(total, lastTotal)}',
              style: TextStyle(fontSize: 11, color: muted),
            )
          : null,
      child: rows.isEmpty
          ? Text(
              isId
                  ? 'Belum ada pengeluaran bulan ini.'
                  : 'No spending this month yet.',
              style: TextStyle(fontSize: 12, color: muted),
            )
          : Column(
              children: [
                for (final r in rows.take(5))
                  _ShareRow(
                    label: r.key,
                    amount: r.value,
                    share: total > 0 ? r.value / total : 0,
                    note: change(r.value, lastMonth[r.key] ?? 0),
                    color: AppTheme.expenseColor,
                  ),
              ],
            ),
    );
  }
}

/// Open debts: what I owe and what others owe me, plus the next due date.
class DebtsSummaryCard extends StatelessWidget {
  final List<DebtModel> debts;
  final bool isId;
  final VoidCallback onOpen;

  const DebtsSummaryCard({
    super.key,
    required this.debts,
    required this.isId,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final open = debts.where((d) => d.status == DebtStatus.active).toList();
    final iOwe = open
        .where((d) => d.type == DebtType.hutang)
        .fold<double>(0, (s, d) => s + d.remainingAmount);
    final owedToMe = open
        .where((d) => d.type == DebtType.piutang)
        .fold<double>(0, (s, d) => s + d.remainingAmount);
    final dated = open.where((d) => d.dueDate != null).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final next = dated.isEmpty ? null : dated.first;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget figure(String label, double value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(value),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: _CardShell(
        icon: Icons.swap_horiz_rounded,
        title: isId ? 'Hutang & piutang' : 'Debts',
        trailing: Icon(Icons.chevron_right_rounded, size: 18, color: muted),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                figure(
                  isId ? 'Saya berhutang' : 'I owe',
                  iOwe,
                  AppTheme.expenseColor,
                ),
                figure(
                  isId ? 'Orang lain berhutang' : 'Owed to me',
                  owedToMe,
                  AppTheme.incomeColor,
                ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 10),
              Text(
                '${isId ? 'Jatuh tempo terdekat' : 'Next due'}: ${next.personName}, '
                '${MaterialLocalizations.of(context).formatMediumDate(next.dueDate!)}',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Where the balance heads in 30 days if the last 3 months repeat.
class ForecastCard extends StatelessWidget {
  final PredictionResult prediction;
  final double currentBalance;
  final bool isId;

  const ForecastCard({
    super.key,
    required this.prediction,
    required this.currentBalance,
    required this.isId,
  });

  @override
  Widget build(BuildContext context) {
    final end = prediction.predictedEndBalance;
    final diff = end - currentBalance;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return _CardShell(
      icon: Icons.insights_rounded,
      title: isId ? 'Perkiraan 30 hari' : '30-day outlook',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CurrencyFormatter.format(end),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: end < 0 ? AppTheme.expenseColor : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isId
                ? 'Saldo keseluruhan dalam 30 hari (${diff >= 0 ? 'naik' : 'turun'} ${CurrencyFormatter.format(diff.abs())}), '
                      'kalau pola 3 bulan terakhir berlanjut.'
                : 'Overall balance in 30 days (${diff >= 0 ? 'up' : 'down'} ${CurrencyFormatter.format(diff.abs())}) '
                      'if the last 3 months repeat.',
            style: TextStyle(fontSize: 12, color: muted, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '${isId ? 'Rata-rata per hari' : 'Daily average'}: '
            '+${CurrencyFormatter.format(prediction.averageDailyIncome)} / '
            '-${CurrencyFormatter.format(prediction.averageDailyExpense)}',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
  }
}

/// Shown when part of the data could not be loaded, instead of silently
/// presenting empty sections.
class LoadIssueBanner extends StatelessWidget {
  final bool isId;
  final VoidCallback onRetry;

  const LoadIssueBanner({super.key, required this.isId, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isId
                  ? 'Sebagian data belum termuat, angka bisa belum lengkap.'
                  : 'Some data did not load, so figures may be incomplete.',
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(isId ? 'Coba lagi' : 'Retry'),
          ),
        ],
      ),
    );
  }
}
