import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/statement_parser.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/expense/presentation/providers/expense_provider.dart';
import 'package:family_finance_manager/features/income/presentation/providers/income_provider.dart';

/// Review screen for a scanned transaction list (mutasi rekening): every row
/// can be ticked off, switched between money in and out, and given a
/// category. Rows that look already recorded start unticked.
class StatementImportPage extends ConsumerStatefulWidget {
  final List<StatementItem> items;

  const StatementImportPage({super.key, required this.items});

  @override
  ConsumerState<StatementImportPage> createState() =>
      _StatementImportPageState();
}

class _Row {
  final StatementItem item;
  bool selected;
  bool isIncome;
  String category;
  final bool maybeDuplicate;

  _Row({
    required this.item,
    required this.selected,
    required this.isIncome,
    required this.category,
    required this.maybeDuplicate,
  });
}

class _StatementImportPageState extends ConsumerState<StatementImportPage> {
  late final List<_Row> _rows;
  bool _saving = false;
  int _done = 0;

  static const _hintWords = {
    'groceries': ['belanja', 'kebutuhan', 'groceries', 'shopping', 'sembako'],
    'food': ['makan', 'food', 'kuliner', 'jajan'],
    'transfer': ['transfer', 'kirim'],
    'transfer_in': ['transfer', 'lain', 'other'],
    'salary': ['gaji', 'salary', 'upah'],
    'refund': ['refund', 'cashback', 'lain', 'other'],
  };

  String _pick(String? hint, List<String> categories, List<String> fallback) {
    for (final word in _hintWords[hint] ?? const <String>[]) {
      for (final c in categories) {
        if (c.toLowerCase().contains(word)) return c;
      }
    }
    return categories.isNotEmpty ? categories.first : fallback.first;
  }

  List<String> get _incomeCategories => ref.read(
    effectiveIncomeCategoriesProvider(ref.read(financeScopeIdProvider)),
  );
  List<String> get _expenseCategories => ref.read(
    effectiveExpenseCategoriesProvider(ref.read(financeScopeIdProvider)),
  );

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    final scope = ref.read(financeScopeIdProvider);
    final incomes = ref.read(incomeStreamProvider(scope)).valueOrNull ?? [];
    final expenses = ref.read(expenseStreamProvider(scope)).valueOrNull ?? [];
    _rows = [
      for (final item in widget.items)
        () {
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
          return _Row(
            item: item,
            selected: !dup,
            isIncome: item.isIncome,
            category: item.isIncome
                ? _pick(
                    item.categoryHint,
                    _incomeCategories,
                    AppConstants.incomeCategories,
                  )
                : _pick(
                    item.categoryHint,
                    _expenseCategories,
                    AppConstants.expenseCategories,
                  ),
            maybeDuplicate: dup,
          );
        }(),
    ];
  }

  Future<void> _save(bool isId) async {
    final chosen = _rows.where((r) => r.selected).toList();
    if (chosen.isEmpty) return;
    final scope = ref.read(financeScopeIdProvider);
    final uid = ref.read(firebaseAuthDataSourceProvider).currentUser?.uid ?? '';
    setState(() {
      _saving = true;
      _done = 0;
    });
    var failed = 0;
    for (final r in chosen) {
      final date = r.item.date ?? DateTime.now();
      final note = r.item.description.isEmpty ? null : r.item.description;
      String? error;
      if (r.isIncome) {
        error = await ref
            .read(incomeNotifierProvider.notifier)
            .addIncome(
              IncomeModel(
                id: '',
                familyId: scope,
                userId: uid,
                amount: r.item.amount,
                category: r.category,
                note: note,
                date: date,
              ),
            );
      } else {
        error = await ref
            .read(expenseNotifierProvider.notifier)
            .addExpense(
              ExpenseModel(
                id: '',
                familyId: scope,
                userId: uid,
                amount: r.item.amount,
                category: r.category,
                note: note,
                date: date,
              ),
            );
      }
      if (error != null) failed++;
      if (mounted) setState(() => _done++);
    }
    ref.invalidate(dashboardProvider);
    if (!mounted) return;
    final saved = chosen.length - failed;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? (isId
                    ? '$saved transaksi tersimpan.'
                    : '$saved transactions saved.')
              : (isId
                    ? '$saved tersimpan, $failed gagal. Coba simpan ulang yang gagal.'
                    : '$saved saved, $failed failed. Try those again.'),
        ),
        backgroundColor: failed == 0
            ? AppTheme.incomeColor
            : AppTheme.errorColor,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final scheme = Theme.of(context).colorScheme;
    final chosen = _rows.where((r) => r.selected).toList();
    final totalIn = chosen
        .where((r) => r.isIncome)
        .fold<double>(0, (s, r) => s + r.item.amount);
    final totalOut = chosen
        .where((r) => !r.isIncome)
        .fold<double>(0, (s, r) => s + r.item.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(isId ? 'Impor mutasi' : 'Import transactions'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              isId
                  ? 'Cek dulu sebelum disimpan. Yang sepertinya sudah pernah dicatat tidak dicentang. Top up e-wallet atau pindah ke rekening sendiri bisa kamu lepas centangnya.'
                  : 'Check before saving. Rows that look already recorded start unticked. Untick e-wallet top-ups or moves between your own accounts.',
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
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _RowTile(
                row: _rows[i],
                isId: isId,
                enabled: !_saving,
                incomeCategories: _incomeCategories,
                expenseCategories: _expenseCategories,
                onChanged: () => setState(() {}),
                pickFor: (row, isIncome) => isIncome
                    ? _pick(
                        row.item.categoryHint,
                        _incomeCategories,
                        AppConstants.incomeCategories,
                      )
                    : _pick(
                        row.item.categoryHint,
                        _expenseCategories,
                        AppConstants.expenseCategories,
                      ),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${isId ? 'Masuk' : 'In'} ${CurrencyFormatter.format(totalIn)}  ·  ${isId ? 'Keluar' : 'Out'} ${CurrencyFormatter.format(totalOut)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving || chosen.isEmpty
                          ? null
                          : () => _save(isId),
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
                                  : 'Save ${chosen.length} transactions'),
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
  final List<String> incomeCategories;
  final List<String> expenseCategories;
  final VoidCallback onChanged;
  final String Function(_Row row, bool isIncome) pickFor;

  const _RowTile({
    required this.row,
    required this.isId,
    required this.enabled,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.onChanged,
    required this.pickFor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = row.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;
    final categories = row.isIncome ? incomeCategories : expenseCategories;
    final options = categories.contains(row.category)
        ? categories
        : [row.category, ...categories];

    return Opacity(
      opacity: row.selected ? 1 : 0.55,
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
              value: row.selected,
              onChanged: enabled
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
                          '${row.isIncome ? '+' : '-'}${CurrencyFormatter.format(row.item.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
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
                  if (row.maybeDuplicate) ...[
                    const SizedBox(height: 4),
                    Text(
                      isId
                          ? 'Mungkin sudah ada di catatan'
                          : 'May already be recorded',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Tap to switch money in / money out.
                      ActionChip(
                        label: Text(
                          row.isIncome
                              ? (isId ? 'Masuk' : 'In')
                              : (isId ? 'Keluar' : 'Out'),
                        ),
                        avatar: Icon(
                          row.isIncome
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          size: 16,
                          color: color,
                        ),
                        onPressed: enabled
                            ? () {
                                row.isIncome = !row.isIncome;
                                row.category = pickFor(row, row.isIncome);
                                onChanged();
                              }
                            : null,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: row.category,
                          isExpanded: true,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final c in options)
                              DropdownMenuItem(
                                value: c,
                                child: Text(c, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: enabled
                              ? (v) {
                                  if (v == null) return;
                                  row.category = v;
                                  onChanged();
                                }
                              : null,
                        ),
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
