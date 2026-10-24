import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/user_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/widgets/insight_cards.dart';
import 'package:family_finance_manager/features/expense/presentation/pages/expense_page.dart';
import 'package:family_finance_manager/features/family/presentation/providers/family_provider.dart';
import 'package:family_finance_manager/features/income/presentation/pages/income_page.dart';

/// Opens "This month in detail" from the balance card: what came in and
/// went out, newest first, by category and (in a family) by member.
Future<void> showMonthDetailSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const MonthDetailSheet(),
    );

bool _isSavings(String category) =>
    category == 'Tabungan' || category == 'Savings';

bool _thisMonth(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month;
}

class MonthDetailSheet extends ConsumerWidget {
  const MonthDetailSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final data = ref.watch(dashboardProvider).valueOrNull;
    final familyMode = ref.watch(familyIdProvider).isNotEmpty;
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final scheme = Theme.of(context).colorScheme;

    if (data == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final incomes = data.allIncomes.where((e) => _thisMonth(e.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final allOut = data.allExpenses.where((e) => _thisMonth(e.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final spending = allOut.where((e) => !_isSavings(e.category)).toList();
    final toSavings = allOut
        .where((e) => _isSavings(e.category))
        .fold<double>(0, (s, e) => s + e.amount);
    final net = data.monthIncome - data.monthExpense;

    final tabs = <(String, Widget)>[
      (
        isId ? 'Terbaru' : 'Latest',
        _LatestTab(incomes: incomes, expenses: allOut, isId: isId),
      ),
      (
        isId ? 'Pengeluaran' : 'Spending',
        _CategoryTab(
          groups: _groupExpenses(spending),
          income: false,
          isId: isId,
        ),
      ),
      (
        isId ? 'Pemasukan' : 'Income',
        _CategoryTab(groups: _groupIncomes(incomes), income: true, isId: isId),
      ),
      (isId ? 'Perkiraan' : 'Outlook', _OutlookTab(data: data, isId: isId)),
      if (familyMode)
        (
          isId ? 'Per anggota' : 'By member',
          _MemberTab(
            incomes: incomes,
            expenses: data.allExpenses,
            members: members,
            isId: isId,
          ),
        ),
    ];

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: DefaultTabController(
        length: tabs.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isId ? 'Rincian' : 'Details'} ${MaterialLocalizations.of(context).formatMonthYear(DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Total(
                        label: isId ? 'Masuk' : 'In',
                        amount: data.monthIncome,
                        color: AppTheme.incomeColor,
                      ),
                      _Total(
                        label: isId ? 'Keluar' : 'Out',
                        amount: data.monthExpense,
                        color: AppTheme.expenseColor,
                      ),
                      _Total(
                        label: isId ? 'Sisa' : 'Left',
                        amount: net,
                        color: net < 0
                            ? AppTheme.expenseColor
                            : scheme.onSurface,
                      ),
                    ],
                  ),
                  if (toSavings > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      isId
                          ? 'Ke tabungan ${CurrencyFormatter.format(toSavings)} (tidak dihitung pengeluaran)'
                          : 'To savings ${CurrencyFormatter.format(toSavings)} (not counted as spending)',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TabBar(
              isScrollable: tabs.length > 3,
              tabAlignment: tabs.length > 3 ? TabAlignment.start : null,
              tabs: [for (final t in tabs) Tab(text: t.$1)],
            ),
            Expanded(child: TabBarView(children: [for (final t in tabs) t.$2])),
          ],
        ),
      ),
    );
  }

  static Map<String, List<ExpenseModel>> _groupExpenses(
    List<ExpenseModel> list,
  ) {
    final map = <String, List<ExpenseModel>>{};
    for (final e in list) {
      map.putIfAbsent(e.category, () => []).add(e);
    }
    return map;
  }

  static Map<String, List<IncomeModel>> _groupIncomes(List<IncomeModel> list) {
    final map = <String, List<IncomeModel>>{};
    for (final e in list) {
      map.putIfAbsent(e.category, () => []).add(e);
    }
    return map;
  }
}

class _Total extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _Total({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _empty(BuildContext context, String text) => Center(
  child: Padding(
    padding: const EdgeInsets.all(32),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  ),
);

/// One transaction; tap to edit or delete, like on the History tab.
class _TxRow extends ConsumerWidget {
  final IncomeModel? income;
  final ExpenseModel? expense;
  final bool showCategory;
  const _TxRow({this.income, this.expense, this.showCategory = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = income != null;
    final date = income?.date ?? expense!.date;
    final category = income?.category ?? expense!.category;
    final note = (income?.note ?? expense?.note ?? '').trim();
    final amount = income?.amount ?? expense!.amount;
    final savings = !isIncome && _isSavings(category);
    final color = isIncome
        ? AppTheme.incomeColor
        : (savings ? AppTheme.savingsColor : AppTheme.expenseColor);
    final title = showCategory ? category : (note.isEmpty ? category : note);
    final subtitle = [
      DateFormatter.format(date),
      if (showCategory && note.isNotEmpty) note,
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          isIncome
              ? Icons.trending_up
              : (savings ? Icons.savings_outlined : Icons.trending_down),
          size: 18,
          color: color,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'}${CurrencyFormatter.format(amount)}',
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
      onTap: () async {
        if (income != null) {
          await IncomePage.openEditor(context, ref, income!);
        } else {
          await ExpensePage.openEditor(context, ref, expense!);
        }
        ref.invalidate(dashboardProvider);
      },
    );
  }
}

class _LatestTab extends StatelessWidget {
  final List<IncomeModel> incomes;
  final List<ExpenseModel> expenses;
  final bool isId;
  const _LatestTab({
    required this.incomes,
    required this.expenses,
    required this.isId,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <(DateTime, Widget)>[
      for (final e in incomes) (e.date, _TxRow(income: e)),
      for (final e in expenses) (e.date, _TxRow(expense: e)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    if (rows.isEmpty) {
      return _empty(
        context,
        isId ? 'Belum ada transaksi bulan ini.' : 'No transactions this month.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [for (final r in rows) r.$2],
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final Map<String, List<Object>> groups;
  final bool income;
  final bool isId;
  const _CategoryTab({
    required this.groups,
    required this.income,
    required this.isId,
  });

  double _sum(List<Object> list) => list.fold<double>(
    0,
    (s, e) => s + (e is IncomeModel ? e.amount : (e as ExpenseModel).amount),
  );

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _empty(
        context,
        income
            ? (isId
                  ? 'Belum ada pemasukan bulan ini.'
                  : 'No income this month.')
            : (isId
                  ? 'Belum ada pengeluaran bulan ini.'
                  : 'No spending this month.'),
      );
    }
    final total = groups.values.fold<double>(0, (s, l) => s + _sum(l));
    final entries = groups.entries.toList()
      ..sort((a, b) => _sum(b.value).compareTo(_sum(a.value)));
    final color = income ? AppTheme.incomeColor : AppTheme.expenseColor;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        for (final g in entries)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      g.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(_sum(g.value)),
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? _sum(g.value) / total : 0,
                        minHeight: 6,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.12),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${g.value.length} ${isId ? 'transaksi' : (g.value.length == 1 ? 'transaction' : 'transactions')} · ${total > 0 ? (_sum(g.value) / total * 100).round() : 0}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              children: [
                for (final e in g.value)
                  e is IncomeModel
                      ? _TxRow(income: e, showCategory: false)
                      : _TxRow(expense: e as ExpenseModel, showCategory: false),
              ],
            ),
          ),
      ],
    );
  }
}

class _MemberTab extends StatelessWidget {
  final List<IncomeModel> incomes;
  final List<ExpenseModel> expenses;
  final List<UserModel> members;
  final bool isId;
  const _MemberTab({
    required this.incomes,
    required this.expenses,
    required this.members,
    required this.isId,
  });

  @override
  Widget build(BuildContext context) {
    final names = {for (final m in members) m.id: m.name};
    final byUser = <String, double>{};
    for (final e in incomes) {
      byUser[e.userId] = (byUser[e.userId] ?? 0) + e.amount;
    }
    final rows = byUser.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        MemberSpendingCard(expenses: expenses, members: members, isId: isId),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isId ? 'Pemasukan per anggota' : 'Income by member',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                Text(
                  isId
                      ? 'Belum ada pemasukan bulan ini.'
                      : 'No income this month yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            names[r.key] ??
                                (isId ? 'Mantan anggota' : 'Former member'),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(r.value),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.incomeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where the overall balance is heading over the next 30 days if the last
/// three months repeat: a headline number, the path, and the daily averages.
class _OutlookTab extends StatelessWidget {
  final DashboardData data;
  final bool isId;
  const _OutlookTab({required this.data, required this.isId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = data.prediction;
    if (p == null ||
        p.dailyBalances.isEmpty ||
        (data.allIncomes.isEmpty && data.allExpenses.isEmpty)) {
      return _empty(
        context,
        isId
            ? 'Belum cukup data untuk perkiraan. Catat beberapa transaksi dulu.'
            : 'Not enough data for an outlook yet. Record a few transactions first.',
      );
    }
    final now = data.totalBalance;
    final end = p.predictedEndBalance;
    final change = end - now;
    final up = change >= 0;
    // The theme's own primary reads on both light and dark surfaces.
    final line = scheme.primary;
    final spots = [
      for (var i = 0; i < p.dailyBalances.length; i++)
        FlSpot(i.toDouble(), p.dailyBalances[i]),
    ];
    final last = (p.dailyBalances.length - 1).toDouble();

    String dayLabel(int day) {
      if (day == 0) return isId ? 'Hari ini' : 'Today';
      return isId ? '$day hari' : '$day days';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          isId ? 'Saldo 30 hari lagi' : 'Balance in 30 days',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.format(end),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 18,
              color: up ? AppTheme.incomeColor : AppTheme.expenseColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isId
                    ? '${up ? 'Naik' : 'Turun'} ${CurrencyFormatter.format(change.abs())} dari sekarang'
                    : '${up ? 'Up' : 'Down'} ${CurrencyFormatter.format(change.abs())} from now',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: last,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final day = value.round();
                      if (day != 0 && day != 15 && day != last.round()) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(
                          dayLabel(day == last.round() ? 30 : day),
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  getTooltipItems: (touched) => [
                    for (final t in touched)
                      LineTooltipItem(
                        '${dayLabel(t.x.round())}\n${CurrencyFormatter.format(t.y)}',
                        TextStyle(
                          color: scheme.onInverseSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: line,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: line.withValues(alpha: 0.10),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _Total(
              label: isId ? 'Rata-rata masuk / hari' : 'Avg in / day',
              amount: p.averageDailyIncome,
              color: AppTheme.incomeColor,
            ),
            _Total(
              label: isId ? 'Rata-rata keluar / hari' : 'Avg out / day',
              amount: p.averageDailyExpense,
              color: AppTheme.expenseColor,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          isId
              ? 'Perkiraan sederhana: rata-rata 3 bulan terakhir diulang. Ketuk grafik untuk lihat saldo per hari.'
              : 'A simple outlook: the last three months repeated. Touch the chart for each day.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
