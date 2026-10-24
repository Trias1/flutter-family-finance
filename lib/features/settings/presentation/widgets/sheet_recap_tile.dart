import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/sheet_recap_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';

/// Settings row for the monthly recap in the user's own Google Sheets.
/// Nothing is connected until the user picks a Google account here.
class SheetRecapTile extends ConsumerStatefulWidget {
  const SheetRecapTile({super.key});

  @override
  ConsumerState<SheetRecapTile> createState() => _SheetRecapTileState();
}

class _SheetRecapTileState extends ConsumerState<SheetRecapTile> {
  bool _busy = false;

  bool get _isId => ref.read(localeProvider).languageCode == 'id';
  String _t(String id, String en) => _isId ? id : en;

  String _message(String code) => switch (code) {
    'cancelled' => _t('Dibatalkan.', 'Cancelled.'),
    'network' => _t(
      'Tidak ada koneksi. Coba lagi nanti.',
      'No connection. Try again later.',
    ),
    'reconnect' => _t(
      'Akses Google terputus atau spreadsheet tidak ditemukan. Hubungkan ulang.',
      'Google access ended or the spreadsheet is gone. Connect again.',
    ),
    _ => _t(
      'Google menolak permintaan. Coba lagi nanti.',
      'Google refused the request. Try again later.',
    ),
  };

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on SheetRecapException catch (e) {
      if (e.code != 'cancelled') {
        messenger.showSnackBar(SnackBar(content: Text(_message(e.code))));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(_message('google'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Rekap ke Google Sheets', 'Recap to Google Sheets')),
        content: Text(
          _t(
            'Pilih akun Google kamu. Aplikasi membuat satu spreadsheet di Google Drive akun itu, berisi tab per bulan (pengeluaran per kategori, pemasukan, rekap, dan grafik).\n\n'
                'Tiap kali aplikasi dibuka, bulan ini diperbarui. Begitu masuk bulan baru, bulan lalu ditutup dan tab bulan baru dibuat otomatis.\n\n'
                'Data dikirim langsung dari HP ini ke Drive kamu. Aplikasi hanya bisa membuka file yang dibuatnya sendiri, tidak bisa melihat file lain di Drive.',
            'Pick your Google account. The app creates one spreadsheet in that account\'s Google Drive, with a tab per month (spending by category, income, recap and charts).\n\n'
                'Each time the app opens, this month is refreshed. When a new month starts, last month is closed and the new month\'s tab is added automatically.\n\n'
                'Data goes straight from this phone to your Drive. The app can only open files it created, never anything else in your Drive.',
          ),
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('Pilih akun Google', 'Choose Google account')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => ref.read(sheetRecapServiceProvider).connect(isId: _isId),
      _t(
        'Spreadsheet dibuat di Drive kamu.',
        'Spreadsheet created in your Drive.',
      ),
    );
  }

  Future<void> _manage(SheetRecapConfig config) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: Text(_t('Buka spreadsheet', 'Open spreadsheet')),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: Text(_t('Sinkron sekarang', 'Sync now')),
              onTap: () => Navigator.pop(ctx, 'sync'),
            ),
            ListTile(
              leading: const Icon(
                Icons.link_off_rounded,
                color: AppTheme.errorColor,
              ),
              title: Text(
                _t('Putuskan', 'Disconnect'),
                style: const TextStyle(color: AppTheme.errorColor),
              ),
              subtitle: Text(
                _t(
                  'File tetap ada di Drive kamu.',
                  'The file stays in your Drive.',
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'disconnect'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final service = ref.read(sheetRecapServiceProvider);
    switch (choice) {
      case 'open':
        await launchUrl(
          Uri.parse(config.url),
          mode: LaunchMode.externalApplication,
        );
      case 'sync':
        await _run(service.syncNow, _t('Sudah diperbarui.', 'Updated.'));
      case 'disconnect':
        await _run(service.disconnect, _t('Diputuskan.', 'Disconnected.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final config = ref.watch(sheetRecapConfigProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = config == null
        ? _t(
            'Belum terhubung · dibuat di Google Drive kamu sendiri',
            'Not connected · made in your own Google Drive',
          )
        : [
            config.email,
            if (config.lastSync != null)
              _t('sinkron ${config.lastSync}', 'synced ${config.lastSync}'),
          ].join(' · ');
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _busy
            ? null
            : () => config == null ? _connect() : _manage(config),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.incomeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.table_chart_outlined,
                  color: AppTheme.incomeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Rekap ke Google Sheets', 'Recap to Google Sheets'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
