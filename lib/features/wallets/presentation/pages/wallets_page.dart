import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/wallet_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/wallets/presentation/providers/wallet_provider.dart';

class WalletsPage extends ConsumerStatefulWidget {
  const WalletsPage({super.key});

  @override
  ConsumerState<WalletsPage> createState() => _WalletsPageState();
}

class _WalletsPageState extends ConsumerState<WalletsPage> {
  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final walletsAsync = ref.watch(walletStreamProvider(familyId));

    if (familyId.isEmpty) return const SizedBox();

    return Stack(
      children: [
        walletsAsync.when(
          loading: () => const LoadingWidget(message: 'Memuat dompet...'),
          error: (e, _) =>
              AppErrorWidget(message: 'Gagal memuat: $e', onRetry: () {}),
          data: (wallets) {
            if (wallets.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada dompet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _showWalletSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Dompet'),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: wallets.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _TotalBalanceCard(wallets: wallets);
                  }
                  return _WalletCard(
                    wallet: wallets[i - 1],
                    onEdit: () =>
                        _showWalletSheet(context, wallet: wallets[i - 1]),
                  );
                },
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'transfer',
                backgroundColor: AppTheme.primaryColor,
                onPressed: () => _showTransferSheet(context),
                child: const Icon(Icons.swap_horiz),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'add_wallet',
                backgroundColor: AppTheme.savingsColor,
                onPressed: () => _showWalletSheet(context),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showWalletSheet(BuildContext context, {WalletModel? wallet}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WalletFormSheet(wallet: wallet),
    );
  }

  void _showTransferSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _TransferSheet(),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  final List<WalletModel> wallets;
  const _TotalBalanceCard({required this.wallets});

  @override
  Widget build(BuildContext context) {
    final total = wallets.fold<double>(0, (s, w) => s + w.balance);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Saldo',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(total),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${wallets.length} dompet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  final WalletModel wallet;
  final VoidCallback onEdit;
  const _WalletCard({required this.wallet, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeIcon = wallet.type == WalletType.bank
        ? Icons.account_balance
        : wallet.type == WalletType.ewallet
        ? Icons.phone_iphone
        : Icons.money;
    final typeLabel = wallet.type == WalletType.bank
        ? 'Bank'
        : wallet.type == WalletType.ewallet
        ? 'E-Wallet'
        : 'Tunai';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(wallet.balance),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.primaryColor,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Dompet?'),
        content: Text(
          'Dompet "${wallet.name}" akan dihapus. Transaksi lama tidak ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final err = await ref
        .read(walletNotifierProvider.notifier)
        .deleteWallet(wallet.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Dompet berhasil dihapus'),
        backgroundColor: err == null
            ? AppTheme.incomeColor
            : AppTheme.errorColor,
      ),
    );
  }
}

class _WalletFormSheet extends ConsumerStatefulWidget {
  final WalletModel? wallet;
  const _WalletFormSheet({this.wallet});

  @override
  ConsumerState<_WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<_WalletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  WalletType _type = WalletType.cash;

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final wallet = widget.wallet;
    if (wallet != null) {
      _nameController.text = wallet.name;
      _balanceController.text = wallet.balance.toStringAsFixed(0);
      _type = wallet.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                _isEdit ? 'Edit Dompet' : 'Tambah Dompet',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SegmentedButton<WalletType>(
                segments: const [
                  ButtonSegment(
                    value: WalletType.cash,
                    label: Text('Tunai'),
                    icon: Icon(Icons.money, size: 16),
                  ),
                  ButtonSegment(
                    value: WalletType.bank,
                    label: Text('Bank'),
                    icon: Icon(Icons.account_balance, size: 16),
                  ),
                  ButtonSegment(
                    value: WalletType.ewallet,
                    label: Text('E-Wallet'),
                    icon: Icon(Icons.phone_iphone, size: 16),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Dompet',
                  prefixIcon: Icon(Icons.wallet),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nama harus diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _isEdit ? 'Saldo' : 'Saldo Awal',
                  prefixIcon: const Icon(Icons.money),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final wallet = widget.wallet;
    final familyId = ref.read(financeScopeIdProvider);
    final balance =
        double.tryParse(
          _balanceController.text.replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0;
    final data = WalletModel(
      id: wallet?.id ?? '',
      familyId: wallet?.familyId ?? familyId,
      name: _nameController.text.trim(),
      type: _type,
      balance: balance,
      icon: wallet?.icon,
      colorHex: wallet?.colorHex,
      createdAt: wallet?.createdAt,
    );
    final notifier = ref.read(walletNotifierProvider.notifier);
    final err = _isEdit
        ? await notifier.updateWallet(data)
        : await notifier.createWallet(data);
    if (mounted) {
      Navigator.pop(context);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
        );
      } else if (_isEdit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dompet berhasil diperbarui'),
            backgroundColor: AppTheme.incomeColor,
          ),
        );
      }
    }
  }
}

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet();

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _feeController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromWalletId;
  String? _toWalletId;

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final walletsAsync = ref.watch(walletStreamProvider(familyId));
    final wallets = walletsAsync.valueOrNull ?? [];

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
                'Transfer Antar Dompet',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _fromWalletId,
                decoration: const InputDecoration(
                  labelText: 'Dari Dompet',
                  prefixIcon: Icon(Icons.arrow_upward),
                ),
                items: wallets
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          '${w.name} (${CurrencyFormatter.format(w.balance)})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _fromWalletId = v),
                validator: (v) => v == null ? 'Pilih dompet asal' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _toWalletId,
                decoration: const InputDecoration(
                  labelText: 'Ke Dompet',
                  prefixIcon: Icon(Icons.arrow_downward),
                ),
                items: wallets
                    .where((w) => w.id != _fromWalletId)
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          '${w.name} (${CurrencyFormatter.format(w.balance)})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _toWalletId = v),
                validator: (v) => v == null ? 'Pilih dompet tujuan' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Transfer',
                  prefixIcon: Icon(Icons.money),
                ),
                validator: (v) {
                  final n = double.tryParse(
                    v?.replaceAll('.', '').replaceAll(',', '.') ?? '',
                  );
                  if (n == null || n <= 0) return 'Jumlah harus valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Biaya Admin (opsional)',
                  prefixIcon: Icon(Icons.receipt),
                ),
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
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Transfer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final familyId = ref.read(financeScopeIdProvider);
    final amount = double.parse(
      _amountController.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    final fee = double.tryParse(
      _feeController.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    final err = await ref
        .read(walletNotifierProvider.notifier)
        .transfer(
          _fromWalletId!,
          _toWalletId!,
          amount,
          fee,
          _noteController.text.isEmpty ? null : _noteController.text.trim(),
          familyId,
        );
    if (mounted) {
      Navigator.pop(context);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer berhasil'),
            backgroundColor: AppTheme.incomeColor,
          ),
        );
      }
    }
  }
}
