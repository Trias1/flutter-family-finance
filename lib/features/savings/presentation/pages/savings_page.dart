import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/expense/presentation/providers/expense_provider.dart';
import 'package:family_finance_manager/features/savings/presentation/providers/saving_provider.dart';

class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyId = ref.watch(financeScopeIdProvider);
    final savingsAsync = ref.watch(savingStreamProvider(familyId));

    return savingsAsync.when(
      loading: () => const LoadingWidget(message: 'Memuat tabungan...'),
      error: (e, _) => AppErrorWidget(
        message: 'Gagal memuat tabungan: $e',
        onRetry: () => ref.invalidate(savingStreamProvider(familyId)),
      ),
      data: (savings) => Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(savingStreamProvider(familyId)),
            child: savings.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.savings,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada target tabungan',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: savings.length,
                    itemBuilder: (context, index) {
                      final saving = savings[index];
                      final progress = saving.progress;
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.savingsColor
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.savings,
                                          color: AppTheme.savingsColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              saving.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (saving.bankName != null)
                                              Text(
                                                saving.bankName!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit')
                                      _showSavingForm(
                                        context,
                                        ref,
                                        saving: saving,
                                      );
                                    else if (value == 'add')
                                      _showAddMoneyDialog(context, ref, saving);
                                    else if (value == 'withdraw')
                                      _showWithdrawDialog(context, ref, saving);
                                    else if (value == 'delete')
                                      ref
                                          .read(savingNotifierProvider.notifier)
                                          .deleteSaving(saving.id);
                                  },
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(
                                      value: 'add',
                                      child: Text('Tambah Tabungan'),
                                    ),
                                    PopupMenuItem(
                                      value: 'withdraw',
                                      child: Text('Tarik Tabungan'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit Target'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Hapus'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 100
                                      ? AppTheme.incomeColor
                                      : AppTheme.savingsColor,
                                ),
                                minHeight: 10,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${CurrencyFormatter.format(saving.currentAmount)} / ${CurrencyFormatter.format(saving.targetAmount)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '${progress.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Target: ${DateFormatter.format(saving.targetDate)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              backgroundColor: AppTheme.savingsColor,
              onPressed: () => _showSavingForm(context, ref),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _showSavingForm(
    BuildContext context,
    WidgetRef ref, {
    SavingModel? saving,
  }) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: saving?.name ?? '');
    final targetController = TextEditingController(
      text: saving != null ? saving.targetAmount.toString() : '',
    );
    String? selectedBank = saving?.bankName;
    DateTime targetDate =
        saving?.targetDate ?? DateTime.now().add(const Duration(days: 365));

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
                    saving == null ? 'Target Baru' : 'Edit Target',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Target',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Nama tidak boleh kosong'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Target',
                      prefixIcon: Icon(Icons.money),
                      prefixText: 'Rp ',
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Nominal tidak boleh kosong'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Bank',
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    items: AppConstants.allBanks
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => selectedBank = v),
                    validator: (v) => v == null ? 'Pilih bank' : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text('Target: ${DateFormatter.format(targetDate)}'),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );
                      if (date != null) setSheetState(() => targetDate = date);
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final fId = ref.read(financeScopeIdProvider);
                      final model = SavingModel(
                        id: saving?.id ?? '',
                        familyId: fId,
                        name: nameController.text,
                        targetAmount: double.parse(targetController.text),
                        currentAmount: saving?.currentAmount ?? 0,
                        bankName: selectedBank,
                        targetDate: targetDate,
                      );
                      if (saving == null)
                        ref
                            .read(savingNotifierProvider.notifier)
                            .createSaving(model);
                      else
                        ref
                            .read(savingNotifierProvider.notifier)
                            .updateSaving(model);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.savingsColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(saving == null ? 'Buat Target' : 'Simpan'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMoneyDialog(
    BuildContext context,
    WidgetRef ref,
    SavingModel saving,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Tabungan'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nominal',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(savingNotifierProvider.notifier)
                    .addToSaving(saving.id, double.parse(controller.text));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(
    BuildContext context,
    WidgetRef ref,
    SavingModel saving,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarik Tabungan'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nominal',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              final amount = double.parse(controller.text);
              try {
                await ref
                    .read(savingNotifierProvider.notifier)
                    .withdrawFromSaving(saving.id, amount);
                final fId = ref.read(financeScopeIdProvider);
                final uid = ref.read(currentUserProvider).valueOrNull?.id ?? '';
                final expense = ExpenseModel(
                  id: '',
                  familyId: fId,
                  userId: uid,
                  amount: amount,
                  category: 'Tabungan',
                  note: 'Penarikan - ${saving.name}',
                  date: DateTime.now(),
                );
                await ref
                    .read(expenseNotifierProvider.notifier)
                    .addExpense(expense);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
            child: const Text('Tarik'),
          ),
        ],
      ),
    );
  }
}
