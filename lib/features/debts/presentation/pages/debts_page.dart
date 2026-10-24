import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/empty_widget.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/debt_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/debts/presentation/providers/debt_provider.dart';

class DebtsPage extends ConsumerStatefulWidget {
  const DebtsPage({super.key});

  @override
  ConsumerState<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends ConsumerState<DebtsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final debtsAsync = ref.watch(debtStreamProvider(familyId));
    final isId = Localizations.localeOf(context).languageCode == 'id';

    if (familyId.isEmpty) return const SizedBox();

    return Stack(
      children: [
        Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.arrow_upward),
                  text: isId ? 'Hutang' : 'Debts',
                ),
                Tab(
                  icon: const Icon(Icons.arrow_downward),
                  text: isId ? 'Piutang' : 'Receivables',
                ),
              ],
              labelColor: AppTheme.expenseColor,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: AppTheme.expenseColor,
            ),
            Expanded(
              child: debtsAsync.when(
                loading: () => LoadingWidget(
                  message: isId ? 'Memuat hutang...' : 'Loading debts...',
                ),
                error: (e, _) => AppErrorWidget(
                  message: isId
                      ? 'Data hutang belum bisa dimuat. Coba lagi ya.'
                      : "Couldn't load your debts. Try again.",
                  onRetry: () => ref.invalidate(debtStreamProvider(familyId)),
                ),
                data: (allDebts) {
                  final filtered = _tabController.index == 0
                      ? allDebts
                            .where((d) => d.type == DebtType.hutang)
                            .toList()
                      : allDebts
                            .where((d) => d.type == DebtType.piutang)
                            .toList();

                  return RefreshIndicator(
                    onRefresh: () async {},
                    child: filtered.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.25,
                                child: EmptyWidget(
                                  message: _tabController.index == 0
                                      ? (isId
                                            ? 'Belum ada hutang'
                                            : 'No debts yet')
                                      : (isId
                                            ? 'Belum ada piutang'
                                            : 'No receivables yet'),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _DebtCard(
                              debt: filtered[i],
                              onTap: () =>
                                  _showDebtDetail(context, filtered[i]),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: AppTheme.expenseColor,
            foregroundColor: Colors.white,
            onPressed: () => _showAddDebtSheet(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showDebtDetail(BuildContext context, DebtModel debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DebtDetailSheet(debt: debt),
    );
  }

  void _showAddDebtSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddDebtSheet(),
    );
  }
}

class _AddDebtSheet extends ConsumerStatefulWidget {
  const _AddDebtSheet();

  @override
  ConsumerState<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<_AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  DebtType _type = DebtType.hutang;
  DateTime? _dueDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                isId ? 'Tambah Hutang/Piutang' : 'Add Debt/Receivable',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SegmentedButton<DebtType>(
                segments: [
                  ButtonSegment(
                    value: DebtType.hutang,
                    label: Text(isId ? 'Hutang' : 'I owe'),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: DebtType.piutang,
                    label: Text(isId ? 'Piutang' : 'Owed to me'),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _personController,
                decoration: InputDecoration(
                  labelText: isId ? 'Nama Orang' : 'Person',
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? (isId ? 'Nama wajib diisi' : 'Name is required')
                    : null,
              ),
              const SizedBox(height: 12),
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
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: isId
                      ? 'Deskripsi (opsional)'
                      : 'Description (optional)',
                  prefixIcon: const Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        _dueDate ??
                        DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _dueDate = d);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: isId
                        ? 'Jatuh Tempo (opsional)'
                        : 'Due Date (optional)',
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: _dueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _dueDate = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _dueDate != null
                        ? DateFormatter.format(_dueDate!)
                        : (isId ? 'Pilih tanggal' : 'Pick a date'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.expenseColor,
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
    final err = await ref
        .read(debtNotifierProvider.notifier)
        .createDebt(
          DebtModel(
            id: '',
            familyId: familyId,
            userId: userId,
            personName: _personController.text.trim(),
            type: _type,
            amount: amount,
            description: _descController.text.isEmpty
                ? null
                : _descController.text.trim(),
            dueDate: _dueDate,
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
      ref.invalidate(debtStreamProvider(familyId));
      Navigator.pop(context);
    }
  }
}

class _DebtCard extends StatelessWidget {
  final DebtModel debt;
  final VoidCallback onTap;

  const _DebtCard({required this.debt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHutang = debt.type == DebtType.hutang;
    final color = isHutang ? AppTheme.expenseColor : AppTheme.incomeColor;
    final isId = Localizations.localeOf(context).languageCode == 'id';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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
                      isHutang ? Icons.arrow_upward : Icons.arrow_downward,
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
                          debt.personName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (debt.description != null)
                          Text(
                            debt.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(debt.remainingAmount),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${isId ? 'dari' : 'of'} ${CurrencyFormatter.format(debt.amount)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: debt.progress / 100,
                  backgroundColor: color.withValues(alpha: 0.1),
                  color: color,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatusChip(debt: debt),
                  const Spacer(),
                  if (debt.dueDate != null)
                    Text(
                      '${isId ? 'Jatuh tempo' : 'Due'} ${DateFormatter.format(debt.dueDate!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: debt.isOverdue
                            ? AppTheme.errorColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DebtModel debt;
  const _StatusChip({required this.debt});

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    String label;
    Color color;
    IconData icon;

    switch (debt.status) {
      case DebtStatus.paid:
        label = isId ? 'Lunas' : 'Paid';
        color = AppTheme.incomeColor;
        icon = Icons.check_circle;
        break;
      case DebtStatus.cancelled:
        label = isId ? 'Dibatalkan' : 'Cancelled';
        color = AppTheme.errorColor;
        icon = Icons.cancel;
        break;
      case DebtStatus.active:
        if (debt.isOverdue) {
          label = isId ? 'Terlambat' : 'Overdue';
          color = AppTheme.errorColor;
          icon = Icons.warning;
        } else {
          label = isId ? 'Aktif' : 'Active';
          color = AppTheme.primaryColor;
          icon = Icons.schedule;
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtDetailSheet extends ConsumerStatefulWidget {
  final DebtModel debt;
  const _DebtDetailSheet({required this.debt});

  @override
  ConsumerState<_DebtDetailSheet> createState() => _DebtDetailSheetState();
}

class _DebtDetailSheetState extends ConsumerState<_DebtDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(debtPaymentsProvider(widget.debt.id));
    final isHutang = widget.debt.type == DebtType.hutang;
    final color = isHutang ? AppTheme.expenseColor : AppTheme.incomeColor;
    final isActive = widget.debt.status == DebtStatus.active;
    final isId = Localizations.localeOf(context).languageCode == 'id';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: ListView(
          controller: scrollController,
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
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isHutang ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.debt.personName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        isHutang
                            ? (isId ? 'Hutang' : 'Debt')
                            : (isId ? 'Piutang' : 'Receivable'),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(debt: widget.debt),
              ],
            ),
            if (widget.debt.description != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.debt.description!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _InfoBox(
                    label: 'Total',
                    value: CurrencyFormatter.format(widget.debt.amount),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoBox(
                    label: isId ? 'Sisa' : 'Remaining',
                    value: CurrencyFormatter.format(
                      widget.debt.remainingAmount,
                    ),
                    color: color,
                  ),
                ),
              ],
            ),
            if (widget.debt.dueDate != null) ...[
              const SizedBox(height: 12),
              _InfoBox(
                label: isId ? 'Jatuh Tempo' : 'Due Date',
                value: DateFormatter.format(widget.debt.dueDate!),
                color: widget.debt.isOverdue
                    ? AppTheme.errorColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: widget.debt.progress / 100,
                backgroundColor: color.withValues(alpha: 0.1),
                color: color,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.debt.progress.toStringAsFixed(0)}% ${isId ? 'lunas' : 'paid'}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (isActive)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(context),
                  icon: const Icon(Icons.payments_rounded),
                  label: Text(isId ? 'Bayar Cicilan' : 'Make a Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              isId ? 'Riwayat Pembayaran' : 'Payment History',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            paymentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                isId
                    ? 'Riwayat pembayaran belum bisa dimuat.'
                    : "Couldn't load payment history.",
              ),
              data: (payments) {
                if (payments.isEmpty) {
                  return Text(
                    isId ? 'Belum ada pembayaran' : 'No payments yet',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  children: payments
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.payments_rounded,
                                  color: color,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(p.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (p.note != null)
                                      Text(
                                        p.note!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                DateFormatter.format(p.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final s = AppStrings(Localizations.localeOf(context));
    final isId = s.locale.languageCode == 'id';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isId ? 'Bayar Cicilan' : 'Make a Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isId ? 'Jumlah' : 'Amount',
                prefixIcon: const Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: isId ? 'Catatan (opsional)' : 'Note (optional)',
                prefixIcon: const Icon(Icons.note),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(
                amountController.text.replaceAll('.', '').replaceAll(',', '.'),
              );
              if (amount == null || amount <= 0) return;
              final err = await ref
                  .read(debtNotifierProvider.notifier)
                  .addPayment(
                    widget.debt.id,
                    amount,
                    noteController.text.isEmpty ? null : noteController.text,
                  );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(s.saveFailed),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(isId ? 'Bayar' : 'Pay'),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
