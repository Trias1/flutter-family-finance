import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/pages/categories_page.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/core/services/opening_balance.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/income/presentation/providers/income_provider.dart';
import 'package:family_finance_manager/features/reports/presentation/providers/report_provider.dart';
import 'package:family_finance_manager/features/transactions/presentation/providers/transaction_history_provider.dart';
import 'package:family_finance_manager/core/utils/duplicate_check.dart';
import 'package:family_finance_manager/features/family/presentation/providers/family_provider.dart';
import 'package:family_finance_manager/core/services/receipt_parser.dart';

class IncomePage extends ConsumerWidget {
  const IncomePage({super.key});

  /// Opens the form filled from a scanned "money received" screenshot.
  /// Opens the form filled from a scan. Returns what the money is for
  /// ("Untuk") once saved: '' when none was picked, null when not saved.
  static Future<String?> openFromReceipt(
    BuildContext context,
    WidgetRef ref,
    ReceiptDraft draft,
  ) => const IncomePage()._showIncomeForm(context, ref, draft: draft);

  /// Picks one of the user's income categories for a scan, if any fits.
  static String? _categoryFor(String? hint, List<String> categories) {
    const wanted = {
      'salary': ['gaji', 'salary', 'upah'],
      'transfer_in': ['transfer', 'lain', 'other'],
      'opening_balance': ['saldo awal'],
    };
    for (final word in wanted[hint] ?? const <String>[]) {
      for (final c in categories) {
        if (c.toLowerCase().contains(word)) return c;
      }
    }
    return null;
  }

  /// Opens an empty form from other screens, e.g. the + button.
  static Future<void> openNew(BuildContext context, WidgetRef ref) =>
      const IncomePage()._showIncomeForm(context, ref);

  /// Opens the edit form (with delete) from other screens, e.g. History.
  static Future<void> openEditor(
    BuildContext context,
    WidgetRef ref,
    IncomeModel income,
  ) => const IncomePage()._showIncomeForm(context, ref, income: income);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyId = ref.watch(financeScopeIdProvider);
    final incomesAsync = ref.watch(incomeStreamProvider(familyId));
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final s = AppStrings(Localizations.localeOf(context));

    return incomesAsync.when(
      loading: () => LoadingWidget(
        message: isId ? 'Memuat pemasukan...' : 'Loading income...',
      ),
      error: (e, _) => AppErrorWidget(
        message: isId
            ? 'Pemasukan belum bisa dimuat. Coba lagi.'
            : "Couldn't load your income. Try again.",
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
                      isId ? 'Belum ada pemasukan' : 'No income yet',
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
                  foregroundColor: Colors.white,
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
                        title: Text(isId ? 'Hapus Pemasukan' : 'Delete Income'),
                        content: Text(
                          isId
                              ? 'Hapus pemasukan "${income.category}" sebesar ${CurrencyFormatter.format(income.amount)}?'
                              : 'Delete income "${income.category}" of ${CurrencyFormatter.format(income.amount)}?',
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
                foregroundColor: Colors.white,
                onPressed: () => _showIncomeForm(context, ref),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showIncomeForm(
    BuildContext context,
    WidgetRef ref, {
    IncomeModel? income,
    ReceiptDraft? draft,
  }) async {
    final formKey = GlobalKey<FormState>();
    final scanned = draft?.amount;
    final amountController = TextEditingController(
      text: income != null
          ? income.amount.toString()
          : scanned == null
          ? ''
          : (scanned == scanned.roundToDouble()
                ? scanned.toStringAsFixed(0)
                : scanned.toString()),
    );
    final familyId = ref.read(financeScopeIdProvider);
    final categories = ref.read(effectiveIncomeCategoriesProvider(familyId));
    String selectedCategory =
        income?.category ??
        _categoryFor(draft?.categoryHint, categories) ??
        (categories.isNotEmpty
            ? categories.first
            : AppConstants.incomeCategories.first);
    final draftIsId =
        context.mounted && Localizations.localeOf(context).languageCode == 'id';
    final noteController = TextEditingController(
      text: income?.note ?? draft?.noteFor(isId: draftIsId) ?? '',
    );
    DateTime selectedDate = income?.date ?? draft?.date ?? DateTime.now();
    bool isSaving = false;
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final s = AppStrings(Localizations.localeOf(context));
    // Scanned money in: what it is for (Tabungan, Transportasi, ...), kept
    // in front of the note.
    final purposes = draft == null
        ? const <String>[]
        : ref
              .read(effectiveExpenseCategoriesProvider(familyId))
              .where((c) => c != 'Lainnya')
              .toList();
    String? purpose;

    return showModalBottomSheet<String>(
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
                    income == null
                        ? (isId ? 'Tambah Pemasukan' : 'Add Income')
                        : (isId ? 'Edit Pemasukan' : 'Edit Income'),
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
                      setSheetState(
                        () => selectedCategory = v ?? categories.first,
                      );
                    },
                  ),
                  if (purposes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      isId ? 'Untuk (opsional)' : 'For (optional)',
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in purposes)
                          ChoiceChip(
                            label: Text(p),
                            selected: purpose == p,
                            onSelected: (on) =>
                                setSheetState(() => purpose = on ? p : null),
                          ),
                      ],
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
                            if (income == null) {
                              // Ask before saving what looks like a second copy.
                              final scope = ref.read(financeScopeIdProvider);
                              final recent =
                                  ref
                                      .read(incomeStreamProvider(scope))
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
                              final model = IncomeModel(
                                id: income?.id ?? '',
                                familyId: fId,
                                userId: uid,
                                amount: double.parse(amountController.text),
                                category: selectedCategory,
                                note: noteWithPurpose(
                                  noteController.text,
                                  purpose,
                                  isId: isId,
                                ),
                                date: selectedDate,
                              );
                              String? error;
                              if (income == null) {
                                error = await ref
                                    .read(incomeNotifierProvider.notifier)
                                    .addIncome(model);
                              } else {
                                error = await ref
                                    .read(incomeNotifierProvider.notifier)
                                    .updateIncome(model);
                              }
                              if (error != null) throw Exception(error);
                              ref.invalidate(incomeStreamProvider(fId));
                              ref.invalidate(dashboardProvider);
                              ref.invalidate(reportProvider(fId));
                              await ref
                                  .read(transactionHistoryProvider.notifier)
                                  .load(fId);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      income == null
                                          ? (isId
                                                ? 'Pemasukan berhasil ditambahkan'
                                                : 'Income added')
                                          : (isId
                                                ? 'Pemasukan berhasil diperbarui'
                                                : 'Income updated'),
                                    ),
                                    backgroundColor: AppTheme.incomeColor,
                                  ),
                                );
                                Navigator.pop(ctx, purpose ?? '');
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
                      backgroundColor: AppTheme.incomeColor,
                      foregroundColor: Colors.white,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(income == null ? s.add : s.save),
                  ),
                  if (income != null) ...[
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
                                    .read(incomeNotifierProvider.notifier)
                                    .deleteIncome(income.id);
                                if (error != null) throw Exception(error);
                                final fId = ref.read(financeScopeIdProvider);
                                ref.invalidate(incomeStreamProvider(fId));
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
                                            ? 'Pemasukan berhasil dihapus'
                                            : 'Income deleted',
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
                      child: Text(s.delete),
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
