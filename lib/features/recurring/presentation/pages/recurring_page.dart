import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/empty_widget.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/recurring_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/features/recurring/presentation/providers/recurring_provider.dart';

class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {
  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final recurringsAsync = ref.watch(recurringStreamProvider(familyId));
    final isId = Localizations.localeOf(context).languageCode == 'id';

    if (familyId.isEmpty) return const SizedBox();

    return Stack(
      children: [
        recurringsAsync.when(
          loading: () => LoadingWidget(
            message: isId
                ? 'Memuat transaksi berulang...'
                : 'Loading recurring transactions...',
          ),
          error: (e, _) => AppErrorWidget(
            message: isId
                ? 'Transaksi berulang belum bisa dimuat. Coba lagi ya.'
                : "Couldn't load recurring transactions. Try again.",
            onRetry: () => ref.invalidate(recurringStreamProvider(familyId)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyWidget(
                message: isId
                    ? 'Belum ada transaksi berulang'
                    : 'No recurring transactions yet',
              );
            }
            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: list.length,
                itemBuilder: (_, i) => _RecurringCard(recurring: list[i]),
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            onPressed: () => _showAddSheet(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddRecurringSheet(),
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  final RecurringModel recurring;
  const _RecurringCard({required this.recurring});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = recurring.type == 'income';
    final color = isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;
    final s = AppStrings(Localizations.localeOf(context));
    final isId = s.locale.languageCode == 'id';
    final freqLabel = _frequencyLabel(recurring, isId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isIncome ? Icons.trending_up : Icons.trending_down,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recurring.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        freqLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(recurring.amount),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      recurring.isActive
                          ? (isId ? 'Aktif' : 'Active')
                          : (isId ? 'Nonaktif' : 'Paused'),
                      style: TextStyle(
                        fontSize: 11,
                        color: recurring.isActive
                            ? AppTheme.incomeColor
                            : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isId ? 'Berikutnya' : 'Next'}: ${DateFormatter.format(recurring.nextDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: recurring.isActive,
                  onChanged: (_) => ref
                      .read(recurringNotifierProvider.notifier)
                      .toggleActive(recurring),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _frequencyLabel(RecurringModel r, bool isId) {
    final n = r.interval;
    final many = n > 1;
    if (isId) {
      final prefix = many ? 'Setiap $n ' : 'Setiap ';
      switch (r.frequency) {
        case RecurringFrequency.daily:
          return '${prefix}hari';
        case RecurringFrequency.weekly:
          return '${prefix}minggu';
        case RecurringFrequency.monthly:
          final day = r.dayOfMonth ?? r.startDate.day;
          return '${prefix}bulan (tanggal $day)';
        case RecurringFrequency.yearly:
          return '${prefix}tahun';
      }
    }
    switch (r.frequency) {
      case RecurringFrequency.daily:
        return many ? 'Every $n days' : 'Every day';
      case RecurringFrequency.weekly:
        return many ? 'Every $n weeks' : 'Every week';
      case RecurringFrequency.monthly:
        final day = r.dayOfMonth ?? r.startDate.day;
        return '${many ? 'Every $n months' : 'Every month'} (day $day)';
      case RecurringFrequency.yearly:
        return many ? 'Every $n years' : 'Every year';
    }
  }
}

class _AddRecurringSheet extends ConsumerStatefulWidget {
  const _AddRecurringSheet();

  @override
  ConsumerState<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  String _category = '';
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  int? _dayOfMonth;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final incomeCategories = ref.watch(
      effectiveIncomeCategoriesProvider(familyId),
    );
    final expenseCategories = ref.watch(
      effectiveExpenseCategoriesProvider(familyId),
    );
    final categories = _type == 'income' ? incomeCategories : expenseCategories;
    if (_category.isEmpty || !categories.contains(_category)) {
      _category = categories.isNotEmpty ? categories.first : '';
    }
    final s = AppStrings(Localizations.localeOf(context));
    final isId = s.locale.languageCode == 'id';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isId
                    ? 'Tambah Transaksi Berulang'
                    : 'Add Recurring Transaction',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'expense',
                    label: Text(s.expense),
                    icon: const Icon(Icons.trending_down),
                  ),
                  ButtonSegment(
                    value: 'income',
                    label: Text(s.income),
                    icon: const Icon(Icons.trending_up),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isId ? 'Jumlah' : 'Amount',
                  prefixIcon: const Icon(Icons.money),
                ),
                validator: (v) {
                  final n = double.tryParse(
                    v?.replaceAll('.', '').replaceAll(',', '.') ?? '',
                  );
                  if (n == null || n <= 0) return s.invalidAmount;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: categories.contains(_category)
                    ? _category
                    : (categories.isNotEmpty ? categories.first : null),
                decoration: InputDecoration(
                  labelText: isId ? 'Kategori' : 'Category',
                  prefixIcon: const Icon(Icons.category),
                ),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? ''),
              ),
              const SizedBox(height: 12),
              SegmentedButton<RecurringFrequency>(
                segments: [
                  ButtonSegment(
                    value: RecurringFrequency.daily,
                    label: Text(s.daily),
                    icon: const Icon(Icons.today, size: 16),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.weekly,
                    label: Text(s.weekly),
                    icon: const Icon(Icons.date_range, size: 16),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.monthly,
                    label: Text(s.monthly),
                    icon: const Icon(Icons.calendar_month, size: 16),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.yearly,
                    label: Text(s.yearly),
                    icon: const Icon(Icons.event, size: 16),
                  ),
                ],
                selected: {_frequency},
                onSelectionChanged: (v) => setState(() {
                  _frequency = v.first;
                  if (_frequency == RecurringFrequency.monthly) {
                    _dayOfMonth ??= DateTime.now().day;
                  }
                }),
              ),
              if (_frequency == RecurringFrequency.monthly) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _dayOfMonth ?? DateTime.now().day,
                  decoration: InputDecoration(
                    labelText: isId ? 'Tanggal' : 'Day of month',
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  items: List.generate(
                    31,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(isId ? 'Tanggal ${i + 1}' : 'Day ${i + 1}'),
                    ),
                  ),
                  onChanged: (v) => setState(() => _dayOfMonth = v),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: isId ? 'Catatan (opsional)' : 'Note (optional)',
                  prefixIcon: const Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(s.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final familyId = ref.read(financeScopeIdProvider);
    final userId = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    final amount = double.parse(
      _amountController.text.replaceAll('.', '').replaceAll(',', '.'),
    );

    final now = DateTime.now();
    DateTime nextDate;
    switch (_frequency) {
      case RecurringFrequency.daily:
        nextDate = _startDate;
        break;
      case RecurringFrequency.weekly:
        nextDate = _startDate;
        break;
      case RecurringFrequency.monthly:
        final day = _dayOfMonth ?? _startDate.day;
        nextDate = DateTime(_startDate.year, _startDate.month, day);
        if (nextDate.isBefore(now)) {
          nextDate = DateTime(_startDate.year, _startDate.month + 1, day);
        }
        break;
      case RecurringFrequency.yearly:
        nextDate = _startDate;
        if (nextDate.isBefore(now)) {
          nextDate = DateTime(
            _startDate.year + 1,
            _startDate.month,
            _startDate.day,
          );
        }
        break;
    }

    final err = await ref
        .read(recurringNotifierProvider.notifier)
        .createRecurring(
          RecurringModel(
            id: '',
            familyId: familyId,
            userId: userId,
            type: _type,
            amount: amount,
            category: _category,
            note: _noteController.text.isEmpty
                ? null
                : _noteController.text.trim(),
            frequency: _frequency,
            dayOfMonth: _frequency == RecurringFrequency.monthly
                ? (_dayOfMonth ?? _startDate.day)
                : null,
            dayOfWeek: _frequency == RecurringFrequency.weekly
                ? _startDate.weekday
                : null,
            startDate: _startDate,
            endDate: _endDate,
            nextDate: nextDate,
          ),
        );

    if (mounted) {
      if (err != null) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings(Localizations.localeOf(context)).saveFailed,
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      ref.invalidate(recurringStreamProvider(familyId));
      Navigator.pop(context);
    }
  }
}
