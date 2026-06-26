import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/empty_widget.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/features/transactions/presentation/providers/transaction_history_provider.dart';

enum _SortOrder { newest, oldest, highestAmount, lowestAmount }

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  TransactionType? _selectedType;
  _SortOrder _sortOrder = _SortOrder.newest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final familyId = ref.read(financeScopeIdProvider);
      if (familyId.isNotEmpty) {
        ref.read(transactionHistoryProvider.notifier).load(familyId);
      }
    });
  }

  List<TransactionItem> _applyFilters(List<TransactionItem> items) {
    var filtered = items;

    if (_startDate != null) {
      filtered = filtered
          .where(
            (i) =>
                i.date.isAfter(_startDate!.subtract(const Duration(days: 1))),
          )
          .toList();
    }
    if (_endDate != null) {
      filtered = filtered
          .where((i) => i.date.isBefore(_endDate!.add(const Duration(days: 1))))
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (i) =>
                i.category.toLowerCase().contains(q) ||
                (i.note?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered
          .where((i) => _selectedCategories.contains(i.category))
          .toList();
    }
    if (_selectedType != null) {
      filtered = filtered.where((i) => i.type == _selectedType).toList();
    }

    final sorted = List<TransactionItem>.from(filtered);
    switch (_sortOrder) {
      case _SortOrder.newest:
        sorted.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _SortOrder.oldest:
        sorted.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _SortOrder.highestAmount:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _SortOrder.lowestAmount:
        sorted.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    return sorted;
  }

  Future<void> _load() {
    final familyId = ref.read(financeScopeIdProvider);
    return ref.read(transactionHistoryProvider.notifier).load(familyId);
  }

  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final itemsAsync = ref.watch(transactionHistoryProvider);
    final incomeCategories = ref.watch(
      effectiveIncomeCategoriesProvider(familyId),
    );
    final expenseCategories = ref.watch(
      effectiveExpenseCategoriesProvider(familyId),
    );
    final allCategories = {...incomeCategories, ...expenseCategories}.toList()
      ..sort();

    if (familyId.isEmpty) return const SizedBox();

    return Column(
      children: [
        _SearchBar(
          query: _searchQuery,
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        _TypeFilterChips(
          selectedType: _selectedType,
          onChanged: (t) => setState(() => _selectedType = t),
        ),
        if (allCategories.isNotEmpty)
          _CategoryFilterChips(
            categories: allCategories,
            selected: _selectedCategories,
            onToggle: (c) => setState(() {
              if (_selectedCategories.contains(c)) {
                _selectedCategories.remove(c);
              } else {
                _selectedCategories.add(c);
              }
            }),
          ),
        _FilterBar(
          startDate: _startDate,
          endDate: _endDate,
          sortOrder: _sortOrder,
          onStartChanged: (d) => setState(() => _startDate = d),
          onEndChanged: (d) => setState(() => _endDate = d),
          onSortChanged: (s) => setState(() => _sortOrder = s),
          onRefresh: _load,
        ),
        Expanded(
          child: itemsAsync.when(
            loading: () => const LoadingWidget(message: 'Memuat riwayat...'),
            error: (e, _) => AppErrorWidget(
              message: 'Gagal memuat riwayat: $e',
              onRetry: _load,
            ),
            data: (items) {
              final filtered = _applyFilters(items);

              if (filtered.isEmpty) {
                return const EmptyWidget(message: 'Belum ada transaksi');
              }

              return RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    final isIncome = item.type == TransactionType.income;
                    final color = isIncome
                        ? AppTheme.incomeColor
                        : AppTheme.expenseColor;

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
                            child: Icon(
                              isIncome
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.category,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isIncome ? 'Pemasukan' : 'Pengeluaran',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.note != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.note!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(item.amount),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormatter.format(item.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: TextEditingController.fromValue(
          TextEditingValue(text: query),
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Cari kategori atau catatan...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(''),
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _TypeFilterChips extends StatelessWidget {
  final TransactionType? selectedType;
  final ValueChanged<TransactionType?> onChanged;

  const _TypeFilterChips({required this.selectedType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final chips = <_FilterChipData>[
      _FilterChipData('Semua', null, Icons.all_inclusive),
      _FilterChipData('Pemasukan', TransactionType.income, Icons.trending_up),
      _FilterChipData(
        'Pengeluaran',
        TransactionType.expense,
        Icons.trending_down,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: chips.map((c) {
          final active = selectedType == c.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.icon, size: 14, color: active ? Colors.white : null),
                  const SizedBox(width: 4),
                  Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? Colors.white : null,
                    ),
                  ),
                ],
              ),
              selected: active,
              onSelected: (_) => onChanged(active ? null : c.value),
              selectedColor: c.value == TransactionType.income
                  ? AppTheme.incomeColor
                  : c.value == TransactionType.expense
                  ? AppTheme.expenseColor
                  : AppTheme.primaryColor,
              checkmarkColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChipData {
  final String label;
  final TransactionType? value;
  final IconData icon;
  const _FilterChipData(this.label, this.value, this.icon);
}

class _CategoryFilterChips extends StatelessWidget {
  final List<String> categories;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _CategoryFilterChips({
    required this.categories,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((cat) {
            final active = selected.contains(cat);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.white : null,
                  ),
                ),
                selected: active,
                onSelected: (_) => onToggle(cat),
                selectedColor: AppTheme.primaryColor,
                checkmarkColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final _SortOrder sortOrder;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final ValueChanged<_SortOrder> onSortChanged;
  final VoidCallback onRefresh;

  const _FilterBar({
    required this.startDate,
    required this.endDate,
    required this.sortOrder,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onSortChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _DateChip(
              label: startDate == null
                  ? 'Dari'
                  : DateFormatter.format(startDate!),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate:
                      startDate ??
                      DateTime.now().subtract(const Duration(days: 30)),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) onStartChanged(d);
              },
              onClear: startDate == null ? null : () => onStartChanged(null),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward, size: 14),
          ),
          Expanded(
            child: _DateChip(
              label: endDate == null ? 'Ke' : DateFormatter.format(endDate!),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) onEndChanged(d);
              },
              onClear: endDate == null ? null : () => onEndChanged(null),
            ),
          ),
          const SizedBox(width: 4),
          _SortDropdown(sortOrder: sortOrder, onChanged: onSortChanged),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final _SortOrder sortOrder;
  final ValueChanged<_SortOrder> onChanged;

  const _SortDropdown({required this.sortOrder, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortOrder>(
      onSelected: onChanged,
      icon: Icon(
        sortOrder == _SortOrder.newest
            ? Icons.sort_rounded
            : sortOrder == _SortOrder.oldest
            ? Icons.sort_rounded
            : Icons.sort_by_alpha_rounded,
        size: 20,
      ),
      tooltip: 'Urutkan',
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _SortOrder.newest,
          child: _SortItem(
            label: 'Terbaru',
            icon: Icons.arrow_downward,
            active: sortOrder == _SortOrder.newest,
          ),
        ),
        PopupMenuItem(
          value: _SortOrder.oldest,
          child: _SortItem(
            label: 'Tertua',
            icon: Icons.arrow_upward,
            active: sortOrder == _SortOrder.oldest,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _SortOrder.highestAmount,
          child: _SortItem(
            label: 'Termahal',
            icon: Icons.arrow_upward,
            active: sortOrder == _SortOrder.highestAmount,
          ),
        ),
        PopupMenuItem(
          value: _SortOrder.lowestAmount,
          child: _SortItem(
            label: 'Termurah',
            icon: Icons.arrow_downward,
            active: sortOrder == _SortOrder.lowestAmount,
          ),
        ),
      ],
    );
  }
}

class _SortItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  const _SortItem({
    required this.label,
    required this.icon,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: active ? AppTheme.primaryColor : null),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: active ? AppTheme.primaryColor : null,
            fontWeight: active ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateChip({required this.label, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
