import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/transfer_model.dart';
import 'package:family_finance_manager/data/models/wallet_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class QrScannerPage extends ConsumerStatefulWidget {
  const QrScannerPage({super.key});

  @override
  ConsumerState<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends ConsumerState<QrScannerPage> {
  MobileScannerController? _controller;
  String? _scannedData;
  bool _processing = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing || _scannedData != null) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final data = barcode!.rawValue!;
    setState(() => _scannedData = data);
    _processScannedData(data);
  }

  Future<void> _processScannedData(String data) async {
    _processing = true;
    try {
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        if (mounted) _showError('Format QR tidak valid');
        return;
      }

      final toWalletId = parsed['walletId'] as String?;
      final amount = (parsed['amount'] as num?)?.toDouble();
      if (toWalletId == null || amount == null) {
        if (mounted) _showError('Data QR tidak lengkap');
        return;
      }

      final ds = ref.read(firestoreDataSourceProvider);
      final toWallet = await ds.getWallet(toWalletId);
      if (toWallet == null) {
        if (mounted) _showError('Dompet tujuan tidak ditemukan');
        return;
      }

      if (mounted) _showTransferConfirm(ds, toWallet, amount);
    } finally {
      _processing = false;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
    setState(() => _scannedData = null);
    _controller?.start();
  }

  void _showTransferConfirm(
    FirestoreDataSource ds,
    WalletModel toWallet,
    double amount,
  ) {
    final familyId = ref.read(financeScopeIdProvider);
    final walletsFuture = ds.getWallets(familyId);
    String? selectedFromWalletId;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Konfirmasi Transfer',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 16),
                  const SizedBox(width: 8),
                  Text('Tujuan: ${toWallet.name}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.money, size: 16),
                  const SizedBox(width: 8),
                  Text('Jumlah: ${CurrencyFormatter.format(amount)}'),
                ],
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<WalletModel>>(
                future: walletsFuture,
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final wallets = snapshot.data ?? [];
                  final fromWallets =
                      wallets.where((w) => w.id != toWallet.id).toList();
                  if (fromWallets.isEmpty) {
                    return const Text('Tidak ada dompet sumber');
                  }
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Dari Dompet',
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    items: fromWallets
                        .map((w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)))
                        .toList(),
                    onChanged: (v) =>
                        setSheetState(() => selectedFromWalletId = v),
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (selectedFromWalletId == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Pilih dompet sumber'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                    return;
                  }
                  await ds.createTransfer(
                    TransferModel(
                      id: '',
                      familyId: familyId,
                      fromWalletId: selectedFromWalletId!,
                      toWalletId: toWallet.id,
                      amount: amount,
                      date: DateTime.now(),
                    ),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transfer berhasil'),
                        backgroundColor: AppTheme.incomeColor,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Konfirmasi Transfer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Transfer')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          if (_scannedData != null)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Memproses QR...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
