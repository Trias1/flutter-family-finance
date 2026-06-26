import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/core/widgets/empty_widget.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/wishlist_item_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/wishlist/presentation/providers/wishlist_provider.dart';

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final itemsAsync = ref.watch(wishlistProvider(familyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Keinginan')),
      body: itemsAsync.when(
        loading: () => const LoadingWidget(message: 'Memuat...'),
        error: (e, _) => AppErrorWidget(
          message: 'Gagal memuat: $e',
          onRetry: () => ref.invalidate(wishlistProvider(familyId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyWidget(message: 'Belum ada keinginan');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) => _WishlistCard(
              item: items[i],
              onDelete: () {
                ref
                    .read(wishlistNotifierProvider.notifier)
                    .deleteItem(items[i].id);
                ref.invalidate(wishlistProvider(familyId));
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.savingsColor,
        onPressed: () => _showForm(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final savedCtrl = TextEditingController();
    DateTime? deadline;
    WishlistPriority priority = WishlistPriority.medium;
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tambah Keinginan',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Keinginan',
                    prefixIcon: Icon(Icons.emoji_events),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Nama tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target Dana',
                    prefixIcon: Icon(Icons.money),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Target tidak boleh kosong'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: savedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sudah Terkumpul',
                    prefixIcon: Icon(Icons.savings),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<WishlistPriority>(
                  value: priority,
                  decoration: const InputDecoration(
                    labelText: 'Prioritas',
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: WishlistPriority.low,
                      child: Text('Rendah'),
                    ),
                    DropdownMenuItem(
                      value: WishlistPriority.medium,
                      child: Text('Sedang'),
                    ),
                    DropdownMenuItem(
                      value: WishlistPriority.high,
                      child: Text('Tinggi'),
                    ),
                  ],
                  onChanged: (v) => setSheetState(
                    () => priority = v ?? WishlistPriority.medium,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setSheetState(() => deadline = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Target Deadline (opsional)',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      deadline != null
                          ? DateFormatter.format(deadline!)
                          : 'Pilih tanggal',
                    ),
                  ),
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
                    final item = WishlistItemModel(
                      id: '',
                      familyId: fId,
                      name: nameCtrl.text,
                      targetAmount: double.parse(targetCtrl.text),
                      savedAmount: double.tryParse(savedCtrl.text) ?? 0,
                      deadline: deadline,
                      priority: priority,
                      createdAt: DateTime.now(),
                    );
                    await ref
                        .read(wishlistNotifierProvider.notifier)
                        .addItem(item);
                    ref.invalidate(wishlistProvider(fId));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.savingsColor,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
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

class _WishlistCard extends StatelessWidget {
  final WishlistItemModel item;
  final VoidCallback onDelete;

  const _WishlistCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final pct = item.progress;
    final priorityColor = switch (item.priority) {
      WishlistPriority.high => AppTheme.errorColor,
      WishlistPriority.medium => AppTheme.warningColor,
      WishlistPriority.low => AppTheme.incomeColor,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  pct >= 1
                      ? Icons.check_circle
                      : item.isOverdue
                      ? Icons.warning
                      : Icons.emoji_events,
                  color: priorityColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.deadline != null)
                      Text(
                        'Target: ${DateFormatter.format(item.deadline!)}${item.isOverdue ? ' (Terlewat)' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: item.isOverdue
                              ? AppTheme.errorColor
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1 ? AppTheme.incomeColor : priorityColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${CurrencyFormatter.formatWithoutSymbol(item.savedAmount)} / ${CurrencyFormatter.formatWithoutSymbol(item.targetAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
