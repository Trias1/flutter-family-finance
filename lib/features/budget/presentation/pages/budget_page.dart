import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/widgets/empty_widget.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/budget/presentation/providers/budget_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/expense/presentation/providers/expense_provider.dart';
import 'package:family_finance_manager/features/budget/presentation/widgets/budget_expenses_sheet.dart';

class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyId = ref.watch(financeScopeIdProvider);
    final budgetsAsync = ref.watch(budgetsByMonthProvider(familyId));
    // Loaded for each budget's spending list (tap a budget).
    ref.watch(expenseStreamProvider(familyId));
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final s = AppStrings(Localizations.localeOf(context));
    final router = GoRouter.of(context);

    return budgetsAsync.when(
      loading: () => LoadingWidget(
        message: isId ? 'Memuat anggaran...' : 'Loading budgets...',
      ),
      error: (e, _) => AppErrorWidget(
        message: isId
            ? 'Anggaran belum bisa dimuat. Cek koneksi lalu coba lagi.'
            : "Couldn't load budgets. Check your connection and try again.",
        onRetry: () => ref.invalidate(budgetsByMonthProvider(familyId)),
      ),
      data: (budgets) => Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(budgetsByMonthProvider(familyId)),
            child: budgets.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                      ),
                      EmptyWidget(
                        message: isId ? 'Belum ada anggaran' : 'No budgets yet',
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: budgets.length + 1,
                    itemBuilder: (ctx, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => router.push('/budget/history'),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 18,
                                          color: AppTheme.incomeColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isId ? 'Riwayat' : 'History',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.incomeColor,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                      final budget = budgets[index - 1];
                      final isExceeded = budget.isExceeded;
                      final isWarning = budget.isAlmostExceeded;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showBudgetExpenses(
                          context,
                          category: budget.category,
                          month: budget.month,
                          expenses:
                              ref
                                  .read(expenseStreamProvider(familyId))
                                  .valueOrNull ??
                              const [],
                          isId: isId,
                        ),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isExceeded
                                                ? AppTheme.errorColor
                                                      .withValues(alpha: 0.1)
                                                : isWarning
                                                ? AppTheme.warningColor
                                                      .withValues(alpha: 0.1)
                                                : AppTheme.incomeColor
                                                      .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            isExceeded
                                                ? Icons.warning_rounded
                                                : isWarning
                                                ? Icons.info_rounded
                                                : Icons.check_circle_rounded,
                                            color: isExceeded
                                                ? AppTheme.errorColor
                                                : isWarning
                                                ? AppTheme.warningColor
                                                : AppTheme.incomeColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            budget.category,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit')
                                        _showBudgetForm(
                                          context,
                                          ref,
                                          budget: budget,
                                        );
                                      else if (value == 'delete')
                                        ref
                                            .read(
                                              budgetNotifierProvider.notifier,
                                            )
                                            .deleteBudget(budget.id);
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(s.edit),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(s.delete),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: budget.percentage / 100,
                                ),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) => ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: value.clamp(0.0, 1.0),
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isExceeded
                                          ? AppTheme.errorColor
                                          : isWarning
                                          ? AppTheme.warningColor
                                          : AppTheme.incomeColor,
                                    ),
                                    minHeight: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${isId ? 'Terpakai' : 'Used'}: ${CurrencyFormatter.format(budget.usedAmount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '${isId ? 'Sisa' : 'Left'}: ${CurrencyFormatter.format(budget.remaining)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isExceeded
                                          ? AppTheme.errorColor
                                          : AppTheme.incomeColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                budget.rolloverAmount > 0
                                    ? (isId
                                          ? 'Anggaran: ${CurrencyFormatter.format(budget.effectiveBudget)} (+${CurrencyFormatter.format(budget.rolloverAmount)} sisa bulan lalu)'
                                          : 'Budget: ${CurrencyFormatter.format(budget.effectiveBudget)} (+${CurrencyFormatter.format(budget.rolloverAmount)} left from last month)')
                                    : '${isId ? 'Anggaran' : 'Budget'}: ${CurrencyFormatter.format(budget.budgetAmount)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              // rolloverAmount hidden from current budget, shown in history
                            ],
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
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              onPressed: () => _showBudgetForm(context, ref),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _showBudgetForm(
    BuildContext context,
    WidgetRef ref, {
    BudgetModel? budget,
  }) {
    final formKey = GlobalKey<FormState>();
    final familyId = ref.read(financeScopeIdProvider);
    final categories = ref.read(effectiveExpenseCategoriesProvider(familyId));
    String selectedCategory =
        budget?.category ??
        (categories.isNotEmpty
            ? categories.first
            : AppConstants.expenseCategories.first);
    final amountController = TextEditingController(
      text: budget != null ? budget.budgetAmount.toString() : '',
    );
    bool isSaving = false;
    final s = AppStrings(Localizations.localeOf(context));
    final isId = Localizations.localeOf(context).languageCode == 'id';

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  budget == null
                      ? (isId ? 'Atur Anggaran' : 'Set Budget')
                      : (isId ? 'Edit Anggaran' : 'Edit Budget'),
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: categories.contains(selectedCategory)
                      ? selectedCategory
                      : categories.first,
                  decoration: InputDecoration(
                    labelText: isId ? 'Kategori' : 'Category',
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setSheetState(
                    () => selectedCategory =
                        v ?? AppConstants.expenseCategories.first,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isId ? 'Jumlah Anggaran' : 'Budget Amount',
                    prefixIcon: const Icon(Icons.money),
                    prefixText: 'Rp ',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? s.requiredField : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          FocusScope.of(ctx).unfocus();
                          if (!formKey.currentState!.validate()) return;
                          setSheetState(() => isSaving = true);
                          final month =
                              '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
                          final fId = ref.read(financeScopeIdProvider);
                          // A new budget starts from what was already spent this
                          // month; an edited one keeps its usage and rollover.
                          final used =
                              budget?.usedAmount ??
                              await BudgetRepository(
                                dataSource: ref.read(
                                  firestoreDataSourceProvider,
                                ),
                              ).spentInMonth(fId, selectedCategory, month);
                          final model = BudgetModel(
                            id: budget?.id ?? '',
                            familyId: fId,
                            month: month,
                            category: selectedCategory,
                            budgetAmount: double.parse(amountController.text),
                            usedAmount: used,
                            rolloverAmount: budget?.rolloverAmount ?? 0,
                          );
                          if (budget == null)
                            await ref
                                .read(budgetNotifierProvider.notifier)
                                .setBudget(model);
                          else
                            await ref
                                .read(budgetNotifierProvider.notifier)
                                .updateBudget(model);
                          ref.invalidate(budgetsByMonthProvider(fId));
                          ref.invalidate(dashboardProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningColor,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          budget == null
                              ? s.save
                              : (isId ? 'Perbarui' : 'Update'),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
