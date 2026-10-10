import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/pages/dashboard_settings_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final familyId = ref.watch(familyIdProvider);
    final familyAsync = ref.watch(familyProvider);
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final dashboardSections =
        ref.watch(dashboardSectionsProvider).valueOrNull ??
        const {
          'progress': true,
          'calendar': true,
          'menu': true,
          'recent': true,
        };

    return dashboardAsync.when(
      loading: () => const LoadingWidget(message: 'Memuat dashboard...'),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Gagal memuat dashboard: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(dashboardProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ModeCard(
                  userName: user?.name,
                  isFamilyMode: familyId.isNotEmpty,
                  familyName: familyAsync.valueOrNull?.name,
                ),
                const SizedBox(height: 16),
                _BalanceCard(data: data),
                if (dashboardSections['progress'] ?? true) ...[
                  const SizedBox(height: 16),
                  _buildProgressRow(data, isId),
                ],
                if (data.upcomingBills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildUpcomingBills(data, isId),
                ],
                if (dashboardSections['calendar'] ?? true) ...[
                  const SizedBox(height: 16),
                  _buildCalendar(data, isId),
                ],
                if (dashboardSections['menu'] ?? true) ...[
                  const SizedBox(height: 16),
                  _buildMenuGrid(isId),
                ],
                if (dashboardSections['recent'] ?? true) ...[
                  const SizedBox(height: 20),
                  Text(
                    isId ? 'Transaksi Terbaru' : 'Recent Transactions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentTransactions(data, isId),
                ],
                if (data.savings.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildGoalsSummary(data, isId),
                ],
                if (data.budgets.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildBudgetSummary(data, isId),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressRow(DashboardData data, bool isId) {
    final now = DateTime.now();
    final monthIncomes = data.allIncomes.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
    final monthExpenses = data.allExpenses.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
    final monthIncome = monthIncomes.fold<double>(0, (s, e) => s + e.amount);
    // Exclude Tabungan/Savings from expense calculation for budget tracking
    final monthExpense = monthExpenses.where((e) => e.category != 'Tabungan' && e.category != 'Savings').fold<double>(0, (s, e) => s + e.amount);

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;
    final dailyBudget = daysLeft > 0
        ? data.totalBudgetRemaining / daysLeft
        : 0.0;

    // Without any budget this month there is nothing to measure against; show
    // an empty state instead of a full red bar.
    final hasBudget = data.budgets.any(
      (b) => b.category != 'Tabungan' && b.category != 'Savings',
    );
    final budgetUsage = !hasBudget
        ? 0.0
        : data.totalBudgetRemaining > 0
            ? (monthExpense / (monthExpense + data.totalBudgetRemaining)).clamp(0.0, 1.0)
            : 1.0;

    return Column(
      children: [
        Row(
          children: [
            _DayProgressCard(
              daysInMonth: daysInMonth,
              currentDay: now.day,
              isId: isId,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProgressCard(
                icon: Icons.trending_up_rounded,
                title: isId ? 'Pemasukan' : 'Income',
                subtitle: isId ? 'Bulan ini' : 'This month',
                amount: monthIncome,
                color: AppTheme.incomeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProgressCard(
                icon: Icons.trending_down_rounded,
                title: isId ? 'Pengeluaran' : 'Expense',
                subtitle: isId ? 'Bulan ini' : 'This month',
                amount: monthExpense,
                color: AppTheme.expenseColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_rounded, size: 14, color: AppTheme.warningColor),
                  const SizedBox(width: 6),
                  Text(
                    isId ? 'Sisa Anggaran Harian' : 'Daily Budget Left',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (hasBudget)
                    Text(
                      '${CurrencyFormatter.formatWithoutSymbol(data.totalBudgetRemaining)} ${isId ? 'tersisa' : 'left'}',
                      style: TextStyle(fontSize: 11, color: AppTheme.warningColor),
                    ),
                ],
              ),
              if (!hasBudget) ...[
                const SizedBox(height: 6),
                Text(
                  isId
                      ? 'Belum ada budget bulan ini. Atur di tab Budget.'
                      : 'No budget for this month yet. Set one in the Budget tab.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: budgetUsage),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: AppTheme.warningColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(
                      value > 0.9
                          ? AppTheme.expenseColor
                          : value > 0.7
                              ? AppTheme.warningColor
                              : AppTheme.incomeColor,
                    ),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${CurrencyFormatter.formatWithoutSymbol(dailyBudget)} /hari',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(budgetUsage * 100).toStringAsFixed(0)}% ${isId ? 'terpakai' : 'used'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              ],
              // rollover display removed, shown in budget history page
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingBills(DashboardData data, bool isId) {
    final bills = data.upcomingBills;
    if (bills.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('/bills'),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.warningColor),
                const SizedBox(width: 6),
                Text(
                  isId ? 'Tagihan Mendatang' : 'Upcoming Bills',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  isId ? 'Lihat Semua' : 'See All',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                Icon(Icons.chevron_right, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...bills.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: b.dueDate.isBefore(DateTime.now())
                        ? AppTheme.errorColor.withValues(alpha: 0.1)
                        : AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    b.dueDate.isBefore(DateTime.now()) ? Icons.warning_amber_rounded : Icons.receipt_long,
                    size: 14,
                    color: b.dueDate.isBefore(DateTime.now()) ? AppTheme.errorColor : AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(b.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                Text(
                  CurrencyFormatter.format(b.amount),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  _daysUntilDue(b.dueDate, isId),
                  style: TextStyle(
                    fontSize: 10,
                    color: b.dueDate.isBefore(DateTime.now())
                        ? AppTheme.errorColor
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _daysUntilDue(DateTime dueDate, bool isId) {
    final diff = dueDate.difference(DateTime.now()).inDays;
    if (diff < 0) return isId ? 'Terlambat ${-diff} hari' : '${-diff} days overdue';
    if (diff == 0) return isId ? 'Hari ini' : 'Today';
    if (diff == 1) return isId ? 'Besok' : 'Tomorrow';
    return isId ? '$diff hari lagi' : '$diff days left';
  }

  Widget _buildCalendar(DashboardData data, bool isId) {
    final summary = data.dailySummary[_selectedDay];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
            child: Text(
              isId ? 'Aktivitas Bulanan' : 'Monthly Activity',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              leftChevronIcon: const Icon(Icons.chevron_left, size: 20),
              rightChevronIcon: const Icon(Icons.chevron_right, size: 20),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              cellMargin: const EdgeInsets.all(2),
              cellPadding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
              todayTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
              weekendTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              rangeHighlightColor: AppTheme.expenseColor.withValues(alpha: 0.15),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final daySummary = data.dailySummary[date];
                final dayBills = data.billsByDate[date];
                final hasBill = dayBills != null && dayBills.any((b) => b.status != BillStatus.paid);
                final isOutside = date.month != _focusedDay.month;
                if (isOutside) return null;
                final children = <Widget>[];
                if (hasBill) {
                  children.add(
                    Container(
                      width: 4, height: 4,
                      margin: const EdgeInsets.only(bottom: 1),
                      decoration: const BoxDecoration(
                        color: AppTheme.warningColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                if (daySummary != null) {
                  if (daySummary.totalIncome > 0) {
                    children.add(Text(
                      '+${_shortAmount(daySummary.totalIncome, isId)}',
                      style: const TextStyle(fontSize: 7, color: AppTheme.incomeColor, height: 1.1, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ));
                  }
                  if (daySummary.totalExpense > 0) {
                    children.add(Text(
                      '-${_shortAmount(daySummary.totalExpense, isId)}',
                      style: const TextStyle(fontSize: 7, color: AppTheme.expenseColor, height: 1.1, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ));
                  }
                }
                if (children.isEmpty) return null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                );
              },
            ),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _showDayTransactions(data, selected, isId);
            },
            onPageChanged: (focused) {
              setState(() => _focusedDay = focused);
            },
          ),
          if (summary != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormatter.format(_selectedDay),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (summary.totalIncome > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.incomeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isId ? 'Pemasukan' : 'Income',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.incomeColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '+${CurrencyFormatter.format(summary.totalIncome)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.incomeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (summary.totalExpense > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.expenseColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isId ? 'Pengeluaran' : 'Expense',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.expenseColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '-${CurrencyFormatter.format(summary.totalExpense)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.expenseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (summary.totalIncome > 0 || summary.totalExpense > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text(
                            isId ? 'Net' : 'Net',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            CurrencyFormatter.format(summary.net),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: summary.net >= 0
                                  ? AppTheme.incomeColor
                                  : AppTheme.expenseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (summary.incomes.isNotEmpty ||
                      summary.expenses.isNotEmpty)
                    const SizedBox(height: 6),
                  ...summary.expenses.map(
                    (e) => _MiniTransactionRow(
                      icon: Icons.trending_down,
                      category: e.category,
                      note: e.note,
                      amount: e.amount,
                      color: AppTheme.expenseColor,
                    ),
                  ),
                  ...summary.incomes.map(
                    (i) => _MiniTransactionRow(
                      icon: Icons.trending_up,
                      category: i.category,
                      note: i.note,
                      amount: i.amount,
                      color: AppTheme.incomeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildMonthlyProgress(data, isId),
        ],
      ),
    );
  }

  Widget _buildMonthlyProgress(DashboardData data, bool isId) {
    final now = DateTime.now();
    final monthIncomes = data.allIncomes
        .where((i) => i.date.month == now.month && i.date.year == now.year)
        .toList();
    final monthExpenses = data.allExpenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .toList();
    final monthIncome = monthIncomes.fold<double>(0.0, (s, i) => s + i.amount);
    final monthExpense =
        monthExpenses.fold<double>(0.0, (s, e) => s + e.amount);
    final monthNet = monthIncome - monthExpense;
    final ratio = monthIncome > 0 ? (monthExpense / monthIncome).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isId ? 'Progress Bulanan' : 'Monthly Progress',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _progressRow(
            isId ? 'Pemasukan' : 'Income',
            CurrencyFormatter.format(monthIncome),
            AppTheme.incomeColor,
            null,
          ),
          const SizedBox(height: 4),
          _progressRow(
            isId ? 'Pengeluaran' : 'Expense',
            CurrencyFormatter.format(monthExpense),
            AppTheme.expenseColor,
            ratio,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppTheme.expenseColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(
                ratio > 0.9
                    ? AppTheme.expenseColor
                    : ratio > 0.7
                        ? AppTheme.warningColor
                        : AppTheme.incomeColor,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          _progressRow(
            isId ? 'Sisa Bulan Ini' : 'Month Net',
            CurrencyFormatter.format(monthNet),
            monthNet >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
            null,
          ),
        ],
      ),
    );
  }

  Widget _progressRow(String label, String value, Color color, double? ratio) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (ratio != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid(bool isId) {
    final items = isId ? _menuItemsId : _menuItemsEn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                isId ? 'Menu Utama' : 'Main Menu',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _MenuButton(
            icon: items[i].icon,
            label: items[i].label,
            color: items[i].color,
            onTap: () {
              if (items[i].route != null) {
                context.push(items[i].route!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isId ? 'Fitur akan segera hadir!' : 'Coming soon!',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  String _shortAmount(double amount, bool isId) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}${isId ? 'M' : 'B'}';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(amount >= 10000000 ? 0 : 1)}${isId ? 'JT' : 'M'}';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}${isId ? 'RB' : 'K'}';
    }
    return amount.toStringAsFixed(0);
  }

  void _showDayTransactions(DashboardData data, DateTime day, bool isId) {
    final summary = data.dailySummary[day];
    final dayBills = data.billsByDate[day];
    final hasAny = (summary != null && (summary.incomes.isNotEmpty || summary.expenses.isNotEmpty)) ||
        (dayBills != null && dayBills.isNotEmpty);
    if (!hasAny) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              DateFormatter.format(day),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (dayBills != null && dayBills.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isId ? 'Tagihan' : 'Bills',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warningColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...dayBills.map((b) => _MiniTransactionRow(
                icon: b.status == BillStatus.paid ? Icons.check_circle : Icons.receipt_long,
                category: b.name,
                note: b.status == BillStatus.paid ? 'Dibayar' : null,
                amount: b.amount,
                color: b.status == BillStatus.paid ? AppTheme.incomeColor : AppTheme.warningColor,
              )),
              const SizedBox(height: 8),
            ],
            if (summary != null) ...[
            if (summary.totalExpense > 0) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isId ? 'Pengeluaran' : 'Expense',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.expenseColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '-${CurrencyFormatter.format(summary.totalExpense)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.expenseColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...summary.expenses.map(
                (e) => _MiniTransactionRow(
                  icon: Icons.trending_down,
                  category: e.category,
                  note: e.note,
                  amount: e.amount,
                  color: AppTheme.expenseColor,
                ),
              ),
            ],
            if (summary.totalIncome > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.incomeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isId ? 'Pemasukan' : 'Income',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.incomeColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '+${CurrencyFormatter.format(summary.totalIncome)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.incomeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...summary.incomes.map(
                (i) => _MiniTransactionRow(
                  icon: Icons.trending_up,
                  category: i.category,
                  note: i.note,
                  amount: i.amount,
                  color: AppTheme.incomeColor,
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  isId ? 'Saldo Hari Ini' : 'Daily Net',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.format(summary.net),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: summary.net >= 0
                        ? AppTheme.incomeColor
                        : AppTheme.expenseColor,
                  ),
                ),
              ],
            ),
          ],
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildRecentTransactions(DashboardData data, bool isId) {
    if (data.recentIncomes.isEmpty && data.recentExpenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            isId ? 'Belum ada transaksi' : 'No transactions yet',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ...data.recentIncomes
            .take(3)
            .map(
              (e) => _TransactionItem(
                icon: Icons.trending_up,
                title: e.category,
                subtitle: e.note ?? '',
                amount: e.amount,
                color: AppTheme.incomeColor,
                isIncome: true,
              ),
            ),
        ...data.recentExpenses
            .take(3)
            .map(
              (e) => _TransactionItem(
                icon: Icons.trending_down,
                title: e.category,
                subtitle: e.note ?? '',
                amount: e.amount,
                color: AppTheme.expenseColor,
                isIncome: false,
              ),
            ),
      ],
    );
  }

  Widget _buildGoalsSummary(DashboardData data, bool isId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 16, color: AppTheme.savingsColor),
              const SizedBox(width: 6),
              Text(
                isId ? 'Ringkasan Tabungan' : 'Goals Summary',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                CurrencyFormatter.format(data.totalSavings),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.savingsColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...data.savings.take(3).map(
            (s) => InkWell(
              onTap: () => _showSavingHistory(data, s, isId),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${CurrencyFormatter.formatWithoutSymbol(s.currentAmount)} / ${CurrencyFormatter.formatWithoutSymbol(s.targetAmount)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: s.targetAmount > 0
                              ? (s.currentAmount / s.targetAmount).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 6,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(AppTheme.savingsColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSavingHistory(DashboardData data, SavingModel saving, bool isId) {
    // Filter transactions related to this saving (category "Tabungan" or "Savings")
    // For expenses: show all Tabungan/Savings category (not filtered by saving name)
    final relatedIncomes = data.allIncomes.where(
      (i) => (i.category == 'Tabungan' || i.category == 'Savings'),
    ).toList();
    final relatedExpenses = data.allExpenses.where(
      (e) => (e.category == 'Tabungan' || e.category == 'Savings'),
    ).toList();

    // Combine and sort by date
    final allTransactions = <Map<String, dynamic>>[];
    for (final income in relatedIncomes) {
      allTransactions.add({
        'type': 'income',
        'date': income.date,
        'amount': income.amount,
        'note': income.note,
      });
    }
    for (final expense in relatedExpenses) {
      allTransactions.add({
        'type': 'expense',
        'date': expense.date,
        'amount': expense.amount,
        'note': expense.note,
      });
    }
    allTransactions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.flag_rounded, size: 18, color: AppTheme.savingsColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    saving.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isId ? 'Saldo Saat Ini:' : 'Current Balance:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(saving.currentAmount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.savingsColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isId ? 'Histori Transaksi' : 'Transaction History',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (allTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    isId ? 'Belum ada transaksi' : 'No transactions yet',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allTransactions.length,
                  itemBuilder: (_, index) {
                    final txn = allTransactions[index];
                    final isIncome = txn['type'] == 'income';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (isIncome ? AppTheme.incomeColor : AppTheme.expenseColor)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isIncome ? Icons.add : Icons.remove,
                              size: 14,
                              color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isIncome
                                      ? (isId ? 'Setoran' : 'Deposit')
                                      : (isId ? 'Penarikan' : 'Withdrawal'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  DateFormatter.format(txn['date'] as DateTime),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isIncome ? '+' : '-'}${CurrencyFormatter.format(txn['amount'] as double)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSummary(DashboardData data, bool isId) {
    final budgets = data.budgets.take(5).toList();
    if (budgets.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 16, color: AppTheme.warningColor),
              const SizedBox(width: 6),
              Text(
                isId ? 'Anggaran per Kategori' : 'Budget per Category',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...budgets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.category,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatWithoutSymbol(b.usedAmount),
                        style: TextStyle(
                          fontSize: 11,
                          color: b.isExceeded
                              ? AppTheme.expenseColor
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        ' / ${CurrencyFormatter.formatWithoutSymbol(b.budgetAmount)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: b.percentage.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                          b.isExceeded
                              ? AppTheme.expenseColor
                              : b.isAlmostExceeded
                                  ? AppTheme.warningColor
                                  : AppTheme.incomeColor,
                        ),
                      ),
                    ),
                    // rolloverAmount hidden from current budget, shown in history
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniTransactionRow extends StatelessWidget {
  final IconData icon;
  final String category;
  final String? note;
  final double amount;
  final Color color;

  const _MiniTransactionRow({
    required this.icon,
    required this.category,
    required this.note,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              note != null && note!.isNotEmpty ? note! : category,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final String? route;
  const _MenuItemData(this.icon, this.label, this.color, this.route);
}

final _menuItemsEn = [
  _MenuItemData(Icons.flag_rounded, 'Goals', AppTheme.primaryColor, '/savings'),
  _MenuItemData(
    Icons.assessment_rounded,
    'Reports',
    AppTheme.warningColor,
    '/reports',
  ),
  _MenuItemData(
    Icons.swap_horiz_rounded,
    'Debts',
    AppTheme.expenseColor,
    '/debts',
  ),
  _MenuItemData(
    Icons.family_restroom_rounded,
    'Family',
    AppTheme.primaryColor,
    '/family',
  ),
  _MenuItemData(
    Icons.category_rounded,
    'Categories',
    AppTheme.savingsColor,
    '/categories',
  ),
  _MenuItemData(
    Icons.receipt_long_rounded,
    'Bills',
    AppTheme.expenseColor,
    '/bills',
  ),
];

final _menuItemsId = [
  _MenuItemData(
    Icons.flag_rounded,
    'Target',
    AppTheme.primaryColor,
    '/savings',
  ),
  _MenuItemData(
    Icons.assessment_rounded,
    'Laporan',
    AppTheme.warningColor,
    '/reports',
  ),
  _MenuItemData(
    Icons.swap_horiz_rounded,
    'Hutang',
    AppTheme.expenseColor,
    '/debts',
  ),
  _MenuItemData(
    Icons.family_restroom_rounded,
    'Keluarga',
    AppTheme.primaryColor,
    '/family',
  ),
  _MenuItemData(
    Icons.category_rounded,
    'Kategori',
    AppTheme.savingsColor,
    '/categories',
  ),
  _MenuItemData(
    Icons.receipt_long_rounded,
    'Tagihan',
    AppTheme.expenseColor,
    '/bills',
  ),
];

class _ModeCard extends StatelessWidget {
  final String? userName;
  final bool isFamilyMode;
  final String? familyName;

  const _ModeCard({this.userName, required this.isFamilyMode, this.familyName});

  @override
  Widget build(BuildContext context) {
    final color = isFamilyMode ? AppTheme.savingsColor : AppTheme.primaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFamilyMode
                  ? Icons.family_restroom_rounded
                  : Icons.person_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat datang ${userName?.isNotEmpty == true ? userName : 'User'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isFamilyMode ? 'Mode Keluarga' : 'Mode Personal',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFamilyMode
                      ? 'Sudah join ${familyName ?? 'keluarga kamu'}.'
                      : 'Belum join keluarga, data tersimpan pribadi.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isFamilyMode)
            TextButton(
              onPressed: () => context.push('/family'),
              child: const Text('Gabung'),
            ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final DashboardData data;
  const _BalanceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Saldo',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Bulan Ini',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(data.totalBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(
                label: 'Pemasukan',
                amount: data.totalIncome,
                color: Colors.greenAccent,
              ),
              const SizedBox(width: 24),
              _MiniStat(
                label: 'Pengeluaran',
                amount: data.totalExpense,
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${CurrencyFormatter.format(amount)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _PredMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PredMiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double amount;
  final Color color;

  const _ProgressCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.format(amount),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayProgressCard extends StatelessWidget {
  final int daysInMonth;
  final int currentDay;
  final bool isId;

  const _DayProgressCard({
    required this.daysInMonth,
    required this.currentDay,
    required this.isId,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentDay / daysInMonth;
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 4,
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(
                      value > 0.8
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currentDay',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '/$daysInMonth',
                      style: TextStyle(
                        fontSize: 9,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isId ? 'Hari' : 'Day',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double amount;
  final Color color;
  final bool isIncome;

  const _TransactionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${CurrencyFormatter.format(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
            ),
          ),
        ],
      ),
    );
  }
}
