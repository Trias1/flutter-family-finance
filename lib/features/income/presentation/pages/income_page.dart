import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/pages/categories_page.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/income/presentation/providers/income_provider.dart';
import 'package:family_finance_manager/features/reports/presentation/providers/report_provider.dart';
import 'package:family_finance_manager/features/savings/presentation/providers/saving_provider.dart';
import 'package:family_finance_manager/features/transactions/presentation/providers/transaction_history_provider.dart';

class IncomePage extends ConsumerWidget {
  const IncomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyId = ref.watch(financeScopeIdProvider);
    final incomesAsync = ref.watch(incomeStreamProvider(familyId));

    return incomesAsync.when(
      loading: () => const LoadingWidget(message: 'Memuat pemasukan...'),
      error: (e, _) => AppErrorWidget(
        message: 'Gagal memuat pemasukan: $e',
        onRetry: () => ref.invalidate(incomeStreamProvider(familyId)),
      ),
      data: (incomes) {
        if (incomes.isEmpty) {
          return Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada pemasukan',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  backgroundColor: AppTheme.incomeColor,
                  onPressed: () => _showIncomeForm(context, ref),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(incomeStreamProvider(familyId)),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: incomes.length,
                itemBuilder: (context, index) {
                  final income = incomes[index];
                  return Dismissible(
                    key: ValueKey(income.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) => showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus Pemasukan'),
                        content: Text(
                          'Hapus pemasukan "${income.category}" sebesar ${CurrencyFormatter.format(income.amount)}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                            ),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) => ref
                        .read(incomeNotifierProvider.notifier)
                        .deleteIncome(income.id),
                    child: Container(
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () =>
                            _showIncomeForm(context, ref, income: income),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.incomeColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.trending_up,
                                color: AppTheme.incomeColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    income.category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    income.note ??
                                        DateFormatter.format(income.date),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(income.amount),
                                  style: const TextStyle(
                                    color: AppTheme.incomeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  DateFormatter.format(income.date),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                backgroundColor: AppTheme.incomeColor,
                onPressed: () => _showIncomeForm(context, ref),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showIncomeForm(
    BuildContext context,
    WidgetRef ref, {
    IncomeModel? income,
  }) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: income != null ? income.amount.toString() : '',
    );
    final familyId = ref.read(financeScopeIdProvider);
    final categories = ref.read(effectiveIncomeCategoriesProvider(familyId));
    String selectedCategory =
        income?.category ??
        (categories.isNotEmpty
            ? categories.first
            : AppConstants.incomeCategories.first);
    final noteController = TextEditingController(text: income?.note ?? '');
    DateTime selectedDate = income?.date ?? DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    income == null ? 'Tambah Pemasukan' : 'Edit Pemasukan',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal',
                      prefixIcon: Icon(Icons.money),
                      prefixText: 'Rp ',
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Nominal tidak boleh kosong'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: categories.contains(selectedCategory)
                        ? selectedCategory
                        : categories.first,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: [
                      ...categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                      DropdownMenuItem(
                        value: '__add_category__',
                        child: Text(
                          '+ Tambah Kategori',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == '__add_category__') {
                        Navigator.pop(ctx);
                        _showAddCategorySheet(context, ref);
                        return;
                      }
                      setSheetState(
                        () => selectedCategory = v ?? categories.first,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(DateFormatter.format(selectedDate)),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null)
                        setSheetState(() => selectedDate = date);
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                      FocusScope.of(ctx).unfocus();
                      if (!formKey.currentState!.validate()) return;
                      setSheetState(() => isSaving = true);
                      final fId = ref.read(financeScopeIdProvider);
                      final uid =
                          ref.read(currentUserProvider).valueOrNull?.id ?? '';
                      final model = IncomeModel(
                        id: income?.id ?? '',
                        familyId: fId,
                        userId: uid,
                        amount: double.parse(amountController.text),
                        category: selectedCategory,
                        note: noteController.text.isEmpty
                            ? null
                            : noteController.text,
                        date: selectedDate,
                      );
                      if (income == null) {
                        await ref
                            .read(incomeNotifierProvider.notifier)
                            .addIncome(model);
                      } else {
                        await ref
                            .read(incomeNotifierProvider.notifier)
                            .updateIncome(model);
                      }
                      ref.invalidate(incomeStreamProvider(fId));
                      ref.invalidate(dashboardProvider);
                      ref.invalidate(reportProvider(fId));
                      await ref.read(transactionHistoryProvider.notifier).load(fId);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.incomeColor,
                      foregroundColor: Colors.white,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(income == null ? 'Tambah' : 'Simpan'),
                  ),
                  if (income != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                        FocusScope.of(ctx).unfocus();
                        setSheetState(() => isSaving = true);
                        await ref
                            .read(incomeNotifierProvider.notifier)
                            .deleteIncome(income.id);
                        final fId = ref.read(financeScopeIdProvider);
                        ref.invalidate(incomeStreamProvider(fId));
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(reportProvider(fId));
                        await ref.read(transactionHistoryProvider.notifier).load(fId);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                      ),
                      child: const Text('Hapus'),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context, WidgetRef ref) {
    final familyId = ref.read(financeScopeIdProvider);
    final categories =
        ref.read(categoryStreamProvider(familyId)).valueOrNull ?? [];
    final existingNames = categories
        .where((c) => c.type == 'income')
        .map((c) => c.name)
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          AddCategorySheet(type: 'income', existingNames: existingNames),
    );
  }
}
