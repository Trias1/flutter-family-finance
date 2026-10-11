import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/amount_privacy.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/pages/dashboard_settings_page.dart';
import 'package:family_finance_manager/data/models/debt_model.dart';
import 'package:family_finance_manager/features/dashboard/presentation/widgets/insight_cards.dart';
import 'package:family_finance_manager/features/dashboard/presentation/widgets/month_detail_sheet.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  /// The eye on the balance card hides the numbers on Home.
  bool get _hidden => ref.read(hideAmountsProvider);

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final familyId = ref.watch(familyIdProvider);
    final familyAsync = ref.watch(familyProvider);
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final hidden = ref.watch(hideAmountsProvider);
    final dashboardSections =
        ref.watch(dashboardSectionsProvider).valueOrNull ??
        const {'progress': true, 'calendar': true, 'menu': true};

    return dashboardAsync.when(
      loading: () => LoadingWidget(
        message: isId ? 'Memuat dashboard...' : 'Loading dashboard...',
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppTheme.warningColor,
                ),
                const SizedBox(height: 16),
                Text(
                  isId
                      ? 'Dashboard belum bisa dimuat. Cek koneksi internet lalu coba lagi.'
                      : "The dashboard couldn't load. Check your connection and try again.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(dashboardProvider),
                  child: Text(isId ? 'Coba lagi' : 'Try again'),
                ),
              ],
            ),
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
                if (data.failedSections.isNotEmpty) ...[
                  LoadIssueBanner(
                    isId: isId,
                    onRetry: () => ref.invalidate(dashboardProvider),
                  ),
                  const SizedBox(height: 12),
                ],
                if (familyId.isEmpty) ...[
                  _ModeCard(
                    userName: user?.name,
                    isFamilyMode: false,
                    familyName: familyAsync.valueOrNull?.name,
                  ),
                  const SizedBox(height: 16),
                ],
                _BalanceCard(
                  data: data,
                  hidden: hidden,
                  onTap: () => showMonthDetailSheet(context),
                ),
                if (data.upcomingBills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildUpcomingBills(data, isId),
                ],
                if (dashboardSections['calendar'] ?? true) ...[
                  const SizedBox(height: 16),
                  _buildCalendar(data, isId),
                ],
                // Where the money went and the 30-day outlook live in the
                // month details (tap the balance card): Spending, Outlook.
                if (dashboardSections['menu'] ?? true) ...[
                  const SizedBox(height: 16),
                  _buildMenuGrid(isId),
                ],
                if ((dashboardSections['insights'] ?? true) &&
                    data.debts.any((d) => d.status == DebtStatus.active)) ...[
                  const SizedBox(height: 16),
                  DebtsSummaryCard(
                    debts: data.debts,
                    hidden: hidden,
                    isId: isId,
                    onOpen: () => context.push('/debts'),
                  ),
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
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: AppTheme.warningColor,
                ),
                const SizedBox(width: 6),
                Text(
                  isId ? 'Tagihan Mendatang' : 'Upcoming Bills',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  isId ? 'Lihat Semua' : 'See All',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...bills.map(
            (b) => Padding(
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
                      b.dueDate.isBefore(DateTime.now())
                          ? Icons.warning_amber_rounded
                          : Icons.receipt_long,
                      size: 14,
                      color: b.dueDate.isBefore(DateTime.now())
                          ? AppTheme.errorColor
                          : AppTheme.warningColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    moneyText(_hidden, b.amount),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
            ),
          ),
        ],
      ),
    );
  }

  String _daysUntilDue(DateTime dueDate, bool isId) {
    final diff = dueDate.difference(DateTime.now()).inDays;
    if (diff < 0)
      return isId ? 'Terlambat ${-diff} hari' : '${-diff} days overdue';
    if (diff == 0) return isId ? 'Hari ini' : 'Today';
    if (diff == 1) return isId ? 'Besok' : 'Tomorrow';
    return isId ? '$diff hari lagi' : '$diff days left';
  }

  /// The calendar hands out UTC dates while the day totals are keyed by
  /// local dates, and Dart never treats those as equal; look up by the day.
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Widget _buildCalendar(DashboardData data, bool isId) {
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          TableCalendar(
            // Month and weekday names in the app's language.
            locale: isId ? 'id_ID' : 'en_US',
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            // Room under each date for the day's money in and out.
            rowHeight: 62,
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
              rangeHighlightColor: AppTheme.expenseColor.withValues(
                alpha: 0.15,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final daySummary = data.dailySummary[_day(date)];
                final dayBills = data.billsByDate[_day(date)];
                final hasBill =
                    dayBills != null &&
                    dayBills.any((b) => b.status != BillStatus.paid);
                final isOutside = date.month != _focusedDay.month;
                if (isOutside) return null;
                final children = <Widget>[];
                if (hasBill) {
                  children.add(
                    Container(
                      width: 4,
                      height: 4,
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
                    children.add(
                      Text(
                        _hidden
                            ? '•••'
                            : '+${_shortAmount(daySummary.totalIncome, isId)}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.incomeColor,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  if (daySummary.totalExpense > 0) {
                    children.add(
                      Text(
                        _hidden
                            ? '•••'
                            : '-${_shortAmount(daySummary.totalExpense, isId)}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.expenseColor,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
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
        ],
      ),
    );
  }

  // How many shortcuts sit on the dashboard; the rest live under "More".
  static const _visibleMenuItems = 5;

  void _openMenuItem(_MenuItemData item) {
    if (item.route != null) context.push(item.route!);
  }

  Widget _buildMenuGrid(bool isId) {
    final items = isId ? _menuItemsId : _menuItemsEn;
    final shown = items.take(_visibleMenuItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            isId ? 'Menu Utama' : 'Main Menu',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
          itemCount: shown.length + 1,
          itemBuilder: (_, i) {
            if (i == shown.length) {
              return _MenuButton(
                icon: Icons.apps_rounded,
                label: isId ? 'Lainnya' : 'More',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                onTap: () => _showAllMenu(items, isId),
              );
            }
            return _MenuButton(
              icon: shown[i].icon,
              label: shown[i].label,
              color: shown[i].color,
              onTap: () => _openMenuItem(shown[i]),
            );
          },
        ),
      ],
    );
  }

  /// Every shortcut in one sheet, like the "More" grid in Grab or Gojek.
  void _showAllMenu(List<_MenuItemData> items, bool isId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isId ? 'Semua menu' : 'All features',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
                children: [
                  for (final item in items)
                    _SheetMenuItem(
                      item: item,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openMenuItem(item);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortAmount(double amount, bool isId) {
    String n(double v, int digits) {
      final t = v.toStringAsFixed(digits).replaceAll(RegExp(r'\.0$'), '');
      return isId ? t.replaceAll('.', ',') : t;
    }

    if (amount >= 1000000000)
      return '${n(amount / 1000000000, 1)}${isId ? 'M' : 'B'}';
    if (amount >= 1000000) {
      return '${n(amount / 1000000, amount >= 10000000 ? 0 : 1)}${isId ? 'jt' : 'M'}';
    }
    if (amount >= 1000) return '${n(amount / 1000, 0)}${isId ? 'rb' : 'K'}';
    return amount.toStringAsFixed(0);
  }

  void _showDayTransactions(DashboardData data, DateTime day, bool isId) {
    final summary = data.dailySummary[_day(day)];
    final dayBills = data.billsByDate[_day(day)];
    final hasAny =
        (summary != null &&
            (summary.incomes.isNotEmpty || summary.expenses.isNotEmpty)) ||
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
                    color: Theme.of(
                      ctx,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isId ? 'Tagihan' : 'Bills',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...dayBills.map(
                  (b) => _MiniTransactionRow(
                    icon: b.status == BillStatus.paid
                        ? Icons.check_circle
                        : Icons.receipt_long,
                    category: b.name,
                    note: b.status == BillStatus.paid
                        ? (isId ? 'Dibayar' : 'Paid')
                        : null,
                    amount: b.amount,
                    color: b.status == BillStatus.paid
                        ? AppTheme.incomeColor
                        : AppTheme.warningColor,
                  ),
                ),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                moneyText(_hidden, data.totalSavings),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.savingsColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...data.savings
              .take(3)
              .map(
                (s) => InkWell(
                  onTap: () => _showSavingHistory(data, s, isId),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${numberText(_hidden, s.currentAmount)} / ${numberText(_hidden, s.targetAmount)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                  ? (s.currentAmount / s.targetAmount).clamp(
                                      0.0,
                                      1.0,
                                    )
                                  : 0.0,
                              minHeight: 6,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(
                                AppTheme.savingsColor,
                              ),
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
    final relatedIncomes = data.allIncomes
        .where((i) => (i.category == 'Tabungan' || i.category == 'Savings'))
        .toList();
    final relatedExpenses = data.allExpenses
        .where((e) => (e.category == 'Tabungan' || e.category == 'Savings'))
        .toList();

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
    allTransactions.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

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
                  color: Theme.of(
                    ctx,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 18,
                  color: AppTheme.savingsColor,
                ),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                              color:
                                  (isIncome
                                          ? AppTheme.incomeColor
                                          : AppTheme.expenseColor)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isIncome ? Icons.add : Icons.remove,
                              size: 14,
                              color: isIncome
                                  ? AppTheme.incomeColor
                                  : AppTheme.expenseColor,
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
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onSurfaceVariant,
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
                              color: isIncome
                                  ? AppTheme.incomeColor
                                  : AppTheme.expenseColor,
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
              Icon(
                Icons.pie_chart_rounded,
                size: 16,
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: 6),
              Text(
                isId ? 'Anggaran per Kategori' : 'Budget per Category',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
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
                        numberText(_hidden, b.usedAmount),
                        style: TextStyle(
                          fontSize: 11,
                          color: b.isExceeded
                              ? AppTheme.expenseColor
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        ' / ${numberText(_hidden, b.effectiveBudget)}',
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

class _SheetMenuItem extends StatelessWidget {
  final _MenuItemData item;
  final VoidCallback onTap;

  const _SheetMenuItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.2),
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
    Icons.receipt_long_rounded,
    'Bills',
    AppTheme.expenseColor,
    '/bills',
  ),
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
    Icons.autorenew_rounded,
    'Recurring',
    AppTheme.incomeColor,
    '/recurring',
  ),
  _MenuItemData(
    Icons.tune_rounded,
    'Customize',
    AppTheme.primaryColor,
    '/dashboard-settings',
  ),
  _MenuItemData(
    Icons.backup_rounded,
    'Backup',
    AppTheme.savingsColor,
    '/backup',
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
    Icons.receipt_long_rounded,
    'Tagihan',
    AppTheme.expenseColor,
    '/bills',
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
    Icons.autorenew_rounded,
    'Berulang',
    AppTheme.incomeColor,
    '/recurring',
  ),
  _MenuItemData(
    Icons.tune_rounded,
    'Atur Dashboard',
    AppTheme.primaryColor,
    '/dashboard-settings',
  ),
  _MenuItemData(
    Icons.backup_rounded,
    'Cadangan',
    AppTheme.savingsColor,
    '/backup',
  ),
];

class _ModeCard extends StatelessWidget {
  final String? userName;
  final bool isFamilyMode;
  final String? familyName;

  const _ModeCard({this.userName, required this.isFamilyMode, this.familyName});

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final color = isFamilyMode ? AppTheme.savingsColor : AppTheme.primaryColor;
    final name = userName?.isNotEmpty == true
        ? userName!
        : (isId ? 'Pengguna' : 'User');
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
                  isId ? 'Selamat datang $name' : 'Welcome, $name',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isFamilyMode
                      ? (isId ? 'Mode Keluarga' : 'Family Mode')
                      : (isId ? 'Mode Personal' : 'Personal Mode'),
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFamilyMode
                      ? (isId
                            ? 'Sudah join ${familyName ?? 'keluarga kamu'}.'
                            : 'You joined ${familyName ?? 'your family'}.')
                      : (isId
                            ? 'Belum join keluarga, data tersimpan pribadi.'
                            : 'Not in a family yet, your data stays private.'),
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
              child: Text(isId ? 'Gabung' : 'Join'),
            ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final DashboardData data;
  final bool hidden;
  final VoidCallback onTap;
  const _BalanceCard({
    required this.data,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final net = data.monthIncome - data.monthExpense;
    return Material(
      color: AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isId ? 'Sisa uang bulan ini' : 'Left this month',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  HideAmountsButton(
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 18,
                  ),
                  const Spacer(),
                  Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMonthYear(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                moneyText(hidden, net),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 20,
                runSpacing: 4,
                children: [
                  _MiniStat(
                    label: isId ? 'Masuk' : 'In',
                    amount: data.monthIncome,
                    hidden: hidden,
                    color: const Color(0xFFB9DCC6),
                  ),
                  _MiniStat(
                    label: isId ? 'Keluar' : 'Out',
                    amount: data.monthExpense,
                    hidden: hidden,
                    color: const Color(0xFFF0C2BB),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
              const SizedBox(height: 10),
              // The all-time figure is still useful, just not as the headline.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${isId ? 'Saldo keseluruhan' : 'Overall balance'}: ${moneyText(hidden, data.totalBalance)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    isId ? 'Rincian' : 'Details',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final bool hidden;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.amount,
    required this.hidden,
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
          '$label: ${moneyText(hidden, amount)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
          ),
        ),
      ],
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
