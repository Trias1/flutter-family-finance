import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/empty_widget.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/bills/presentation/providers/bill_provider.dart';

class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key});

  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> {
  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final billsAsync = ref.watch(billStreamProvider(familyId));

    if (familyId.isEmpty) return const SizedBox();

    return Stack(
      children: [
        billsAsync.when(
          loading: () => const LoadingWidget(message: 'Memuat tagihan...'),
          error: (e, _) =>
              AppErrorWidget(
                message: 'Gagal memuat: $e',
                onRetry: () => ref.invalidate(billStreamProvider(familyId)),
              ),
          data: (bills) {
            final unpaid = bills.where((b) => b.status != BillStatus.paid).toList();
            final paid = bills.where((b) => b.status == BillStatus.paid).toList();

            return RefreshIndicator(
              onRefresh: () async {},
              child: bills.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.25,
                          child: const EmptyWidget(message: 'Belum ada tagihan'),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      children: [
                        if (unpaid.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'Belum Dibayar (${unpaid.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...unpaid.map((b) => _BillCard(
                            bill: b,
                            onTap: () => _showBillForm(context, bill: b),
                            onTogglePaid: () => _togglePaid(b),
                          )),
                          if (paid.isNotEmpty) const SizedBox(height: 16),
                        ],
                        if (paid.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'Sudah Dibayar (${paid.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...paid.map((b) => _BillCard(
                            bill: b,
                            onTap: () => _showBillForm(context, bill: b),
                            onTogglePaid: () => _togglePaid(b),
                          )),
                        ],
                      ],
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
            onPressed: () => _showBillForm(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _togglePaid(BillModel bill) async {
    final newStatus = bill.status == BillStatus.paid ? BillStatus.unpaid : BillStatus.paid;
    final err = await ref.read(billNotifierProvider.notifier).updateBill(
      bill.copyWith(
        status: newStatus,
        paidDate: newStatus == BillStatus.paid ? DateTime.now() : null,
      ),
    );
    if (mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  void _showBillForm(BuildContext context, {BillModel? bill}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BillFormSheet(bill: bill),
    );
  }
}

class _BillCard extends ConsumerWidget {
  final BillModel bill;
  final VoidCallback onTap;
  final VoidCallback onTogglePaid;

  const _BillCard({
    required this.bill,
    required this.onTap,
    required this.onTogglePaid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaid = bill.status == BillStatus.paid;
    final isOverdue = !isPaid && bill.dueDate.isBefore(DateTime.now());
    final color = isPaid ? AppTheme.incomeColor : (isOverdue ? AppTheme.errorColor : AppTheme.primaryColor);

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
          child: Row(
            children: [
              GestureDetector(
                onTap: onTogglePaid,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPaid ? Icons.check_circle : Icons.pending_actions,
                    color: color,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaid
                          ? 'Dibayar ${DateFormatter.format(bill.paidDate!)}'
                          : 'Jatuh tempo ${DateFormatter.format(bill.dueDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue
                            ? AppTheme.errorColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(bill.amount),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (!isPaid && bill.repeatType != BillRepeatType.none)
                    Text(
                      bill.repeatType == BillRepeatType.weekly
                          ? 'Mingguan'
                          : bill.repeatType == BillRepeatType.monthly
                              ? 'Bulanan'
                              : 'Tahunan',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class BillFormSheet extends ConsumerStatefulWidget {
  final BillModel? bill;
  const BillFormSheet({super.key, this.bill});

  @override
  ConsumerState<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends ConsumerState<BillFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _dueDate;
  BillRepeatType _repeatType = BillRepeatType.none;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.bill != null) {
      _nameController.text = widget.bill!.name;
      _amountController.text = widget.bill!.amount.toStringAsFixed(0);
      _dueDate = widget.bill!.dueDate;
      _repeatType = widget.bill!.repeatType;
      _noteController.text = widget.bill!.note ?? '';
    } else {
      _dueDate = DateTime.now().add(const Duration(days: 7));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.bill != null ? 'Edit Tagihan' : 'Tambah Tagihan',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Tagihan',
                  prefixIcon: Icon(Icons.receipt_long),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Nama harus diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah',
                  prefixIcon: Icon(Icons.money),
                ),
                validator: (v) {
                  final n = double.tryParse(v?.replaceAll('.', '').replaceAll(',', '.') ?? '');
                  if (n == null || n <= 0) return 'Jumlah harus valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d != null) setState(() => _dueDate = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Jatuh Tempo',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormatter.format(_dueDate)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<BillRepeatType>(
                value: _repeatType,
                decoration: const InputDecoration(
                  labelText: 'Ulangi',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: const [
                  DropdownMenuItem(value: BillRepeatType.none, child: Text('Tidak Berulang')),
                  DropdownMenuItem(value: BillRepeatType.weekly, child: Text('Mingguan')),
                  DropdownMenuItem(value: BillRepeatType.monthly, child: Text('Bulanan')),
                  DropdownMenuItem(value: BillRepeatType.yearly, child: Text('Tahunan')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _repeatType = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  prefixIcon: Icon(Icons.note),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simpan'),
                ),
              ),
              if (widget.bill != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _isSubmitting ? null : _delete,
                    icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                    label: const Text('Hapus', style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ),
              ],
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
    final amount = double.parse(_amountController.text.replaceAll('.', '').replaceAll(',', '.'));
    final now = DateTime.now();
    final notifier = ref.read(billNotifierProvider.notifier);

    String? err;
    if (widget.bill != null) {
      err = await notifier.updateBill(widget.bill!.copyWith(
        name: _nameController.text.trim(),
        amount: amount,
        dueDate: _dueDate,
        repeatType: _repeatType,
        note: _noteController.text.isEmpty ? null : _noteController.text.trim(),
      ));
    } else {
      err = await notifier.createBill(BillModel(
        familyId: familyId,
        name: _nameController.text.trim(),
        amount: amount,
        dueDate: _dueDate,
        repeatType: _repeatType,
        createdAt: now,
      ));
    }

    if (mounted) {
      if (err != null) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
        );
        return;
      }
      ref.invalidate(billStreamProvider(familyId));
      Navigator.pop(context);
    }
  }

  void _delete() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final familyId = ref.read(financeScopeIdProvider);
    final err = await ref.read(billNotifierProvider.notifier).deleteBill(widget.bill!.id);
    if (mounted) {
      if (err != null) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
        );
        return;
      }
      ref.invalidate(billStreamProvider(familyId));
      Navigator.pop(context);
    }
  }
}
