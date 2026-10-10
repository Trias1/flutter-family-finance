import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
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
import 'package:family_finance_manager/core/utils/duplicate_check.dart';
import 'package:family_finance_manager/features/family/presentation/providers/family_provider.dart';

class ExpensePage extends ConsumerWidget {
  const ExpensePage({super.key});

  /// Opens an empty form from other screens, e.g. the + button.
  static Future<void> openNew(BuildContext context, WidgetRef ref) =>
      const ExpensePage()._showExpenseForm(context, ref);

  /// Opens the edit form (with delete) from other screens, e.g. History.
  static Future<void> openEditor(
    BuildContext context,
    WidgetRef ref,
    ExpenseModel expense,
  ) => const ExpensePage()._showExpenseForm(context, ref, expense: expense);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyId = ref.watch(financeScopeIdProvider);
    final expensesAsync = ref.watch(expenseStreamProvider(familyId));
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final s = AppStrings(Localizations.localeOf(context));

    return expensesAsync.when(
      loading: () => LoadingWidget(
        message: isId ? 'Memuat pengeluaran...' : 'Loading expenses...',
      ),
      error: (e, _) => AppErrorWidget(
        message: isId
            ? 'Pengeluaran belum bisa dimuat. Coba lagi.'
            : "Couldn't load your expenses. Try again.",
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
                      isId ? 'Belum ada pengeluaran' : 'No expenses yet',
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
                  foregroundColor: Colors.white,
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
                        title: Text(
                          isId ? 'Hapus Pengeluaran' : 'Delete Expense',
                        ),
                        content: Text(
                          isId
                              ? 'Hapus pengeluaran "${expense.category}" sebesar ${CurrencyFormatter.format(expense.amount)}?'
                              : 'Delete expense "${expense.category}" of ${CurrencyFormatter.format(expense.amount)}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(s.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                            ),
                            child: Text(s.delete),
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
                foregroundColor: Colors.white,
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
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final strings = AppStrings(Localizations.localeOf(context));

    await showModalBottomSheet(
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
                    expense == null
                        ? (isId ? 'Tambah Pengeluaran' : 'Add Expense')
                        : (isId ? 'Edit Pengeluaran' : 'Edit Expense'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isId ? 'Nominal' : 'Amount',
                      prefixIcon: const Icon(Icons.money),
                      prefixText: 'Rp ',
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? (isId
                              ? 'Nominal tidak boleh kosong'
                              : 'Amount is required')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: categories.contains(selectedCategory)
                        ? selectedCategory
                        : categories.first,
                    decoration: InputDecoration(
                      labelText: isId ? 'Kategori' : 'Category',
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: [
                      ...categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                      DropdownMenuItem(
                        value: '__add_category__',
                        child: Text(
                          isId ? '+ Tambah Kategori' : '+ Add Category',
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
                      decoration: InputDecoration(
                        labelText: isId
                            ? 'Pilih Target Tabungan'
                            : 'Choose Savings Goal',
                        prefixIcon: const Icon(Icons.savings),
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
                          final match = savings
                              .where((s) => s.id == v)
                              .firstOrNull;
                          if (match != null && noteController.text.isEmpty) {
                            noteController.text = match.name;
                          }
                        });
                      },
                      validator: (v) => v == null
                          ? (isId
                                ? 'Pilih target tabungan'
                                : 'Choose a savings goal')
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: isId
                          ? 'Catatan (opsional)'
                          : 'Note (optional)',
                      prefixIcon: const Icon(Icons.notes),
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
                            if (expense == null) {
                              // Ask before saving what looks like a second copy.
                              final scope = ref.read(financeScopeIdProvider);
                              final recent =
                                  ref
                                      .read(expenseStreamProvider(scope))
                                      .valueOrNull ??
                                  const [];
                              final members =
                                  ref.read(familyMembersProvider).valueOrNull ??
                                  const [];
                              final ok = await confirmIfDuplicate(
                                context: ctx,
                                recent: recent.map(
                                  (e) => (
                                    userId: e.userId,
                                    amount: e.amount,
                                    category: e.category,
                                    createdAt: e.createdAt,
                                  ),
                                ),
                                amount:
                                    double.tryParse(amountController.text) ?? 0,
                                category: selectedCategory,
                                myUid:
                                    ref
                                        .read(firebaseAuthDataSourceProvider)
                                        .currentUser
                                        ?.uid ??
                                    '',
                                memberNames: {
                                  for (final m in members) m.id: m.name,
                                },
                                isId:
                                    Localizations.localeOf(ctx).languageCode ==
                                    'id',
                              );
                              if (!ok) return;
                            }
                            setSheetState(() => isSaving = true);
                            try {
                              final fId = ref.read(financeScopeIdProvider);
                              final uid =
                                  ref
                                      .read(firebaseAuthDataSourceProvider)
                                      .currentUser
                                      ?.uid ??
                                  '';
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
                              await ref
                                  .read(transactionHistoryProvider.notifier)
                                  .load(fId);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      expense == null
                                          ? (isId
                                                ? 'Pengeluaran berhasil ditambahkan'
                                                : 'Expense added')
                                          : (isId
                                                ? 'Pengeluaran berhasil diperbarui'
                                                : 'Expense updated'),
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
                                    content: Text(_friendlyError(e, isId)),
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
                        : Text(expense == null ? strings.add : strings.save),
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
                                await ref
                                    .read(transactionHistoryProvider.notifier)
                                    .load(fId);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isId
                                            ? 'Pengeluaran berhasil dihapus'
                                            : 'Expense deleted',
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
                                      content: Text(_friendlyError(e, isId)),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                }
                              }
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                      ),
                      child: Text(strings.delete),
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

  String _friendlyError(dynamic e, bool isId) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network-request-failed')) {
      return isId ? 'Tidak ada koneksi internet' : 'No internet connection';
    }
    if (msg.contains('permission-denied')) {
      return isId
          ? 'Tidak punya akses untuk menyimpan data'
          : "You don't have permission to save this";
    }
    if (msg.contains('not-found')) {
      return isId ? 'Data tidak ditemukan' : 'Data not found';
    }
    return isId
        ? 'Gagal menyimpan data. Coba lagi.'
        : "Couldn't save. Please try again.";
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
