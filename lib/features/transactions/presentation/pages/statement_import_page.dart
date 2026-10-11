import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/own_accounts.dart';
import 'package:family_finance_manager/core/services/statement_parser.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/expense/presentation/providers/expense_provider.dart';
import 'package:family_finance_manager/features/income/presentation/providers/income_provider.dart';
import 'package:family_finance_manager/features/savings/presentation/providers/saving_provider.dart';

/// What a statement row becomes when saved.
enum RowKind { income, expense, internal, savings }

/// Review screen for a scanned transaction list (mutasi rekening).
///
/// By default only real income is ticked: spending usually arrives through
/// QRIS/receipt scans, so statement spending rows are shown unticked (tick
/// the ones not recorded yet), and transfers between the user's own
/// accounts or family members are neither income nor spending.
class StatementImportPage extends ConsumerStatefulWidget {
  final List<StatementItem> items;
  final List<String> ownNames;

  /// Rows read from bank notifications: spending is as useful as income
  /// there, so everything starts ticked.
  final bool fromNotifications;

  const StatementImportPage({
    super.key,
    required this.items,
    this.ownNames = const [],
    this.fromNotifications = false,
  });

  @override
  ConsumerState<StatementImportPage> createState() =>
      _StatementImportPageState();
}

class _Row {
  final StatementItem item;
  bool selected;
  RowKind kind;
  String category;
  String? goalId;
  final bool maybeDuplicate;
  final bool ownTransfer;

  _Row({
    required this.item,
    required this.selected,
    required this.kind,
    required this.category,
    required this.maybeDuplicate,
    required this.ownTransfer,
  });
}

class _StatementImportPageState extends ConsumerState<StatementImportPage> {
  late final List<_Row> _rows;
  bool _saving = false;
  int _done = 0;
  bool _incomeOnly = true;

  static const _hintWords = {
    'groceries': ['belanja', 'kebutuhan', 'groceries', 'shopping', 'sembako'],
    'food': ['makan', 'food', 'kuliner', 'jajan'],
    'transfer': ['transfer', 'kirim'],
    'transfer_in': ['transfer', 'lain', 'other'],
    'salary': ['gaji', 'salary', 'upah'],
    'refund': ['refund', 'cashback', 'lain', 'other'],
  };

  String get _scope => ref.read(financeScopeIdProvider);

  List<String> get _incomeCategories =>
      ref.read(effectiveIncomeCategoriesProvider(_scope));
  List<String> get _expenseCategories =>
      ref.read(effectiveExpenseCategoriesProvider(_scope));

  String _pick(String? hint, bool income) {
    final categories = income ? _incomeCategories : _expenseCategories;
    for (final word in _hintWords[hint] ?? const <String>[]) {
      for (final c in categories) {
        if (c.toLowerCase().contains(word)) return c;
      }
    }
    if (categories.isNotEmpty) return categories.first;
    return income
        ? AppConstants.incomeCategories.first
        : AppConstants.expenseCategories.first;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Refunds and cashback give back a fee or part of a purchase; they are
  /// not new income, so they are not ticked (the user can still add them).
  bool _isRefund(_Row r) => r.item.categoryHint == 'refund';

  /// Money-in rows worth recording: green on the bank screen, minus refunds.
  bool _isRealIncome(_Row r) => r.item.isIncome && !_isRefund(r);

  /// The default tick for a row under the current filter.
  bool _defaultSelected(_Row r) {
    if (r.maybeDuplicate || r.kind == RowKind.internal || _isRefund(r)) {
      return false;
    }
    if (r.kind == RowKind.income) return true;
    return !_incomeOnly;
  }

  @override
  void initState() {
    super.initState();
    _incomeOnly = !widget.fromNotifications;
    final incomes = ref.read(incomeStreamProvider(_scope)).valueOrNull ?? [];
    final expenses = ref.read(expenseStreamProvider(_scope)).valueOrNull ?? [];
    _rows = [];
    for (final item in widget.items) {
      final date = item.date;
      // Same direction, amount and day as something already saved.
      final dup =
          date != null &&
          (item.isIncome
              ? incomes.any(
                  (e) =>
                      (e.amount - item.amount).abs() < 0.5 &&
                      _sameDay(e.date, date),
                )
              : expenses.any(
                  (e) =>
                      (e.amount - item.amount).abs() < 0.5 &&
                      _sameDay(e.date, date),
                ));
      // Topping up an e-wallet only moves your own money.
      final own =
          item.categoryHint == 'topup' ||
          OwnAccounts.isOwnTransfer(item.description, widget.ownNames);
      final row = _Row(
        item: item,
        selected: false,
        kind: own
            ? RowKind.internal
            : (item.isIncome ? RowKind.income : RowKind.expense),
        category: _pick(item.categoryHint, item.isIncome),
        maybeDuplicate: dup,
        ownTransfer: own,
      );
      row.selected = _defaultSelected(row);
      _rows.add(row);
    }
  }

  void _setFilter(bool incomeOnly) {
    setState(() {
      _incomeOnly = incomeOnly;
      for (final r in _rows) {
        r.selected = _defaultSelected(r);
      }
    });
  }

  Future<void> _save(bool isId, List<SavingModel> goals) async {
    final chosen = _rows
        .where((r) => r.selected && r.kind != RowKind.internal)
        .toList();
    if (chosen.isEmpty) return;
    final uid = ref.read(firebaseAuthDataSourceProvider).currentUser?.uid ?? '';
    setState(() {
      _saving = true;
      _done = 0;
    });
    var failed = 0;
    for (final r in chosen) {
      final date = r.item.date ?? DateTime.now();
      final desc = r.item.description;
      String? error;
      switch (r.kind) {
        case RowKind.income:
          error = await ref
              .read(incomeNotifierProvider.notifier)
              .addIncome(
                IncomeModel(
                  id: '',
                  familyId: _scope,
                  userId: uid,
                  amount: r.item.amount,
                  category: r.category,
                  note: desc.isEmpty ? null : desc,
                  date: date,
                ),
              );
        case RowKind.expense:
          error = await ref
              .read(expenseNotifierProvider.notifier)
              .addExpense(
                ExpenseModel(
                  id: '',
                  familyId: _scope,
                  userId: uid,
                  amount: r.item.amount,
                  category: r.category,
                  note: desc.isEmpty ? null : desc,
                  date: date,
                ),
              );
        case RowKind.savings:
          // "Tabungan" with the goal's name in the note credits that goal and
          // is never counted as spending.
          final goal = goals.where((g) => g.id == r.goalId).firstOrNull;
          error = await ref
              .read(expenseNotifierProvider.notifier)
              .addExpense(
                ExpenseModel(
                  id: '',
                  familyId: _scope,
                  userId: uid,
                  amount: r.item.amount,
                  category: 'Tabungan',
                  note: goal == null ? desc : '${goal.name} · $desc',
                  date: date,
                ),
              );
        case RowKind.internal:
          break;
      }
      if (error != null) failed++;
      if (mounted) setState(() => _done++);
    }
    ref.invalidate(dashboardProvider);
    if (!mounted) return;
    final saved = chosen.length - failed;
    // Rows keep the statement's dates, so an older month's transfer does not
    // change this month's totals; say where they went.
    final now = DateTime.now();
    final months = <DateTime>{
      for (final r in chosen)
        if (r.item.date != null)
          DateTime(r.item.date!.year, r.item.date!.month),
    }.where((m) => m.year != now.year || m.month != now.month).toList()..sort();
    final format = MaterialLocalizations.of(context).formatMonthYear;
    final where = months.isEmpty
        ? ''
        : (isId
              ? ' · masuk ke ${months.map(format).join(', ')}'
              : ' · recorded in ${months.map(format).join(', ')}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? (isId
                    ? '$saved transaksi tersimpan$where.'
                    : '$saved ${saved == 1 ? 'transaction' : 'transactions'} saved$where.')
              : (isId
                    ? '$saved tersimpan, $failed gagal. Coba simpan ulang yang gagal.'
                    : '$saved saved, $failed failed. Try those again.'),
        ),
        backgroundColor: failed == 0
            ? AppTheme.incomeColor
            : AppTheme.errorColor,
      ),
    );
    // Tells the caller the rows were handled (bank notifications leave the
    // waiting list).
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final scheme = Theme.of(context).colorScheme;
    final goals = ref.watch(savingStreamProvider(_scope)).valueOrNull ?? [];
    final chosen = _rows
        .where((r) => r.selected && r.kind != RowKind.internal)
        .toList();
    final totalIn = chosen
        .where((r) => r.kind == RowKind.income)
        .fold<double>(0, (s, r) => s + r.item.amount);
    final totalOut = chosen
        .where((r) => r.kind != RowKind.income)
        .fold<double>(0, (s, r) => s + r.item.amount);
    // "Income only" shows just the money-in rows (green on the bank screen).
    final visible = _incomeOnly
        ? _rows.where((r) => _isRealIncome(r) || r.selected).toList()
        : _rows;
    final hidden = _rows.length - visible.length;
    final needsGoal = chosen.any(
      (r) => r.kind == RowKind.savings && r.goalId == null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fromNotifications
              ? (isId ? 'Dari notifikasi bank' : 'From bank notifications')
              : (isId ? 'Impor mutasi' : 'Import transactions'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(isId ? 'Pemasukan saja' : 'Income only'),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(isId ? 'Semua' : 'All'),
                ),
              ],
              selected: {_incomeOnly},
              showSelectedIcon: false,
              onSelectionChanged: _saving ? null : (s) => _setFilter(s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Text(
              _incomeOnly
                  ? (isId
                        ? 'Pengeluaran biasanya sudah tercatat lewat scan QRIS atau struk, jadi tidak dicentang. Centang yang belum tercatat (misalnya bayar pakai kartu debit). Pindah antar rekening sendiri tidak dihitung.'
                        : 'Spending usually comes in through QRIS or receipt scans, so it starts unticked. Tick anything not recorded yet (e.g. debit card). Moves between your own accounts are not counted.')
                  : (isId
                        ? 'Semua transaksi dicentang, kecuali yang sepertinya sudah ada dan pindah antar rekening sendiri.'
                        : 'Everything is ticked except rows that look already recorded and moves between your own accounts.'),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: visible.length + (hidden > 0 ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => i == visible.length
                  ? TextButton(
                      onPressed: _saving ? null : () => _setFilter(false),
                      child: Text(
                        isId
                            ? '$hidden transaksi lain disembunyikan · Tampilkan'
                            : '$hidden other rows hidden · Show',
                      ),
                    )
                  : _RowTile(
                      row: visible[i],
                      isId: isId,
                      enabled: !_saving,
                      goals: goals,
                      categoriesFor: (income) =>
                          income ? _incomeCategories : _expenseCategories,
                      onKind: (kind) => setState(() {
                        final r = visible[i];
                        r.kind = kind;
                        if (kind == RowKind.income || kind == RowKind.expense) {
                          r.category = _pick(
                            r.item.categoryHint,
                            kind == RowKind.income,
                          );
                        }
                        r.selected = kind != RowKind.internal;
                      }),
                      onChanged: () => setState(() {}),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${isId ? 'Masuk' : 'In'} ${CurrencyFormatter.format(totalIn)}  ·  ${isId ? 'Keluar' : 'Out'} ${CurrencyFormatter.format(totalOut)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (needsGoal) ...[
                    const SizedBox(height: 4),
                    Text(
                      isId
                          ? 'Pilih target tabungan untuk baris Tabungan.'
                          : 'Pick a savings goal for the Savings rows.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving || chosen.isEmpty || needsGoal
                          ? null
                          : () => _save(isId, goals),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _saving
                            ? (isId
                                  ? 'Menyimpan $_done/${chosen.length}…'
                                  : 'Saving $_done/${chosen.length}…')
                            : (isId
                                  ? 'Simpan ${chosen.length} transaksi'
                                  : 'Save ${chosen.length} ${chosen.length == 1 ? 'transaction' : 'transactions'}'),
                      ),
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
}

class _RowTile extends StatelessWidget {
  final _Row row;
  final bool isId;
  final bool enabled;
  final List<SavingModel> goals;
  final List<String> Function(bool income) categoriesFor;
  final ValueChanged<RowKind> onKind;
  final VoidCallback onChanged;

  const _RowTile({
    required this.row,
    required this.isId,
    required this.enabled,
    required this.goals,
    required this.categoriesFor,
    required this.onKind,
    required this.onChanged,
  });

  String _label(RowKind k) => switch (k) {
    RowKind.income => isId ? 'Pemasukan' : 'Income',
    RowKind.expense => isId ? 'Pengeluaran' : 'Spending',
    RowKind.internal => isId ? 'Pindah rekening' : 'Own transfer',
    RowKind.savings => isId ? 'Tabungan' : 'Savings',
  };

  Color _color(RowKind k) => switch (k) {
    RowKind.income => AppTheme.incomeColor,
    RowKind.expense => AppTheme.expenseColor,
    RowKind.internal => AppTheme.primaryColor,
    RowKind.savings => AppTheme.savingsColor,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(row.kind);
    final sign = row.item.isIncome ? '+' : '-';
    final isEntry = row.kind == RowKind.income || row.kind == RowKind.expense;
    final categories = isEntry
        ? categoriesFor(row.kind == RowKind.income)
        : const <String>[];
    final options = categories.contains(row.category)
        ? categories
        : [row.category, ...categories];

    return Opacity(
      opacity: row.selected && row.kind != RowKind.internal ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: row.selected && row.kind != RowKind.internal,
              onChanged: enabled && row.kind != RowKind.internal
                  ? (v) {
                      row.selected = v ?? false;
                      onChanged();
                    }
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$sign${CurrencyFormatter.format(row.item.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: row.item.isIncome
                                ? AppTheme.incomeColor
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        row.item.date == null
                            ? (isId ? 'Hari ini' : 'Today')
                            : DateFormatter.format(row.item.date!),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                  if (row.maybeDuplicate || row.ownTransfer) ...[
                    const SizedBox(height: 4),
                    Text(
                      row.ownTransfer
                          ? (isId
                                ? 'Ke/dari rekening sendiri atau keluarga'
                                : 'To/from your own or family account')
                          : (isId
                                ? 'Mungkin sudah ada di catatan'
                                : 'May already be recorded'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PopupMenuButton<RowKind>(
                        enabled: enabled,
                        onSelected: onKind,
                        itemBuilder: (_) => [
                          for (final k in RowKind.values)
                            PopupMenuItem(value: k, child: Text(_label(k))),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _label(row.kind),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: color,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isEntry)
                        DropdownButton<String>(
                          value: row.category,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final c in options)
                              DropdownMenuItem(value: c, child: Text(c)),
                          ],
                          onChanged: enabled
                              ? (v) {
                                  if (v == null) return;
                                  row.category = v;
                                  onChanged();
                                }
                              : null,
                        ),
                      if (row.kind == RowKind.savings)
                        goals.isEmpty
                            ? Text(
                                isId
                                    ? 'Belum ada target tabungan'
                                    : 'No savings goals yet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            : DropdownButton<String>(
                                value: row.goalId,
                                isDense: true,
                                hint: Text(
                                  isId ? 'Pilih target' : 'Pick a goal',
                                ),
                                underline: const SizedBox.shrink(),
                                items: [
                                  for (final g in goals)
                                    DropdownMenuItem(
                                      value: g.id,
                                      child: Text(g.name),
                                    ),
                                ],
                                onChanged: enabled
                                    ? (v) {
                                        row.goalId = v;
                                        onChanged();
                                      }
                                    : null,
                              ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
