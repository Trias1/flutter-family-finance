import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/pages/categories_page.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/expense/presentation/providers/expense_provider.dart';
import 'package:family_finance_manager/features/reports/presentation/providers/report_provider.dart';

import 'package:family_finance_manager/features/transactions/presentation/providers/transaction_history_provider.dart';

class ExpensePage extends ConsumerWidget {
  const ExpensePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyId = ref.watch(financeScopeIdProvider);
    final expensesAsync = ref.watch(expenseStreamProvider(familyId));

    return expensesAsync.when(
      loading: () => const LoadingWidget(message: 'Memuat pengeluaran...'),
      error: (e, _) => AppErrorWidget(
        message: 'Gagal memuat pengeluaran: $e',
        onRetry: () => ref.invalidate(expenseStreamProvider(familyId)),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.trending_down,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada pengeluaran',
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
                  backgroundColor: AppTheme.expenseColor,
                  onPressed: () => _showExpenseForm(context, ref),
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
                  ref.invalidate(expenseStreamProvider(familyId)),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  return Dismissible(
                    key: ValueKey(expense.id),
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
                        title: const Text('Hapus Pengeluaran'),
                        content: Text(
                          'Hapus pengeluaran "${expense.category}" sebesar ${CurrencyFormatter.format(expense.amount)}?',
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
                        .read(expenseNotifierProvider.notifier)
                        .deleteExpense(expense.id),
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
                            _showExpenseForm(context, ref, expense: expense),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.expenseColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.trending_down,
                                color: AppTheme.expenseColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    expense.note ??
                                        DateFormatter.format(expense.date),
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
                                  CurrencyFormatter.format(expense.amount),
                                  style: const TextStyle(
                                    color: AppTheme.expenseColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  DateFormatter.format(expense.date),
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
                backgroundColor: AppTheme.expenseColor,
                onPressed: () => _showExpenseForm(context, ref),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showExpenseForm(
    BuildContext context,
    WidgetRef ref, {
    ExpenseModel? expense,
  }) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: expense != null ? expense.amount.toString() : '',
    );
    final familyId = ref.read(financeScopeIdProvider);
    final categories = ref.read(effectiveExpenseCategoriesProvider(familyId));
    final dataSource = ref.read(firestoreDataSourceProvider);
    final savings = await dataSource.getSavings(familyId);
    String selectedCategory =
        expense?.category ??
        (categories.isNotEmpty
            ? categories.first
            : AppConstants.expenseCategories.first);
    final noteController = TextEditingController(text: expense?.note ?? '');
    DateTime selectedDate = expense?.date ?? DateTime.now();
    String? selectedSavingId;
    bool isSaving = false;

    if (!context.mounted) return;

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
                    expense == null ? 'Tambah Pengeluaran' : 'Edit Pengeluaran',
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
                      setSheetState(() {
                        selectedCategory = v ?? categories.first;
                        selectedSavingId = null;
                      });
                    },
                  ),
                  if (selectedCategory == 'Tabungan') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedSavingId,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Target Tabungan',
                        prefixIcon: Icon(Icons.savings),
                      ),
                      items: savings
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setSheetState(() {
                          selectedSavingId = v;
                          final match = savings.where((s) => s.id == v).firstOrNull;
                          if (match != null && noteController.text.isEmpty) {
                            noteController.text = match.name;
                          }
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Pilih target tabungan' : null,
                    ),
                  ],
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
                      if (isSaving) return;
                      FocusScope.of(ctx).unfocus();
                      if (!formKey.currentState!.validate()) return;
                      setSheetState(() => isSaving = true);
                      try {
                        final fId = ref.read(financeScopeIdProvider);
                        final uid =
                            ref.read(currentUserProvider).valueOrNull?.id ?? '';
                        final model = ExpenseModel(
                          id: expense?.id ?? '',
                          familyId: fId,
                          userId: uid,
                          amount: double.parse(amountController.text),
                          category: selectedCategory,
                          note: noteController.text.isEmpty
                              ? null
                              : noteController.text,
                          date: selectedDate,
                        );
                        String? error;
                        if (expense == null) {
                          error = await ref
                              .read(expenseNotifierProvider.notifier)
                              .addExpense(model);
                        } else {
                          error = await ref
                              .read(expenseNotifierProvider.notifier)
                              .updateExpense(model);
                        }
                        if (error != null) throw Exception(error);
                        ref.invalidate(expenseStreamProvider(fId));
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(reportProvider(fId));
                        await ref.read(transactionHistoryProvider.notifier).load(fId);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                expense == null
                                    ? 'Pengeluaran berhasil ditambahkan'
                                    : 'Pengeluaran berhasil diperbarui',
                              ),
                              backgroundColor: AppTheme.incomeColor,
                            ),
                          );
                          Navigator.pop(ctx);
                        }
                      } catch (e) {
                        setSheetState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                _friendlyError(e),
                              ),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.expenseColor,
                      foregroundColor: Colors.white,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(expense == null ? 'Tambah' : 'Simpan'),
                  ),
                  if (expense != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                        if (isSaving) return;
                        FocusScope.of(ctx).unfocus();
                        setSheetState(() => isSaving = true);
                        try {
                          final error = await ref
                              .read(expenseNotifierProvider.notifier)
                              .deleteExpense(expense.id);
                          if (error != null) throw Exception(error);
                          final fId = ref.read(financeScopeIdProvider);
                          ref.invalidate(expenseStreamProvider(fId));
                          ref.invalidate(dashboardProvider);
                          ref.invalidate(reportProvider(fId));
                          await ref.read(transactionHistoryProvider.notifier).load(fId);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Pengeluaran berhasil dihapus'),
                                backgroundColor: AppTheme.incomeColor,
                              ),
                            );
                            Navigator.pop(ctx);
                          }
                        } catch (e) {
                          setSheetState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(_friendlyError(e)),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        }
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

  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network-request-failed')) return 'Tidak ada koneksi internet';
    if (msg.contains('permission-denied')) return 'Tidak punya akses untuk menyimpan data';
    if (msg.contains('not-found')) return 'Data tidak ditemukan';
    return 'Gagal menyimpan data. Coba lagi.';
  }

  void _showAddCategorySheet(BuildContext context, WidgetRef ref) {
    final familyId = ref.read(financeScopeIdProvider);
    final categories =
        ref.read(categoryStreamProvider(familyId)).valueOrNull ?? [];
    final existingNames = categories
        .where((c) => c.type == 'expense')
        .map((c) => c.name)
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          AddCategorySheet(type: 'expense', existingNames: existingNames),
    );
  }
}
