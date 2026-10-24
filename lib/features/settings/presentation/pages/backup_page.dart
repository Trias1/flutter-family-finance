import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/services/backup_service.dart';
import 'package:family_finance_manager/core/services/drive_backup_service.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class _SectionTile extends StatelessWidget {
  final String title;
  const _SectionTile({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  final _backupService = BackupService();
  final _driveService = DriveBackupService();
  bool _isLoading = false;

  bool get _id => ref.read(localeProvider).languageCode == 'id';
  String _t(String id, String en) => _id ? id : en;

  Future<void> _backupLocal() async {
    setState(() => _isLoading = true);
    try {
      final familyId = ref.read(financeScopeIdProvider);
      final ds = ref.read(firestoreDataSourceProvider);
      final backup = await _backupService.collectData(ds, familyId);
      await _backupService.shareBackup(backup);
    } catch (e) {
      if (mounted)
        _showError(_t('Backup gagal. Coba lagi.', 'Backup failed. Try again.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _backupDrive() async {
    setState(() => _isLoading = true);
    try {
      final familyId = ref.read(financeScopeIdProvider);
      final ds = ref.read(firestoreDataSourceProvider);
      final backup = await _backupService.collectData(ds, familyId);
      final success = await _driveService.uploadBackup(backup);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? _t(
                      'Backup tersimpan di Google Drive',
                      'Backup saved to Google Drive',
                    )
                  : _t(
                      'Backup ke Drive gagal. Pastikan kamu masuk dengan Google.',
                      'Drive backup failed. Make sure you signed in with Google.',
                    ),
            ),
            backgroundColor: success
                ? AppTheme.incomeColor
                : AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        _showError(
          _t(
            'Backup ke Drive gagal. Coba lagi.',
            'Drive backup failed. Try again.',
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFromDrive() async {
    setState(() => _isLoading = true);
    try {
      final files = await _driveService.listBackups();
      setState(() => _isLoading = false);
      if (files.isEmpty) {
        if (mounted)
          _showError(
            _t('Belum ada backup di Drive', 'No backups in Drive yet'),
          );
        return;
      }
      if (!mounted) return;
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('Pilih backup', 'Choose a backup')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (_, i) {
                final f = files[i];
                final name = f['name'] as String? ?? '';
                return ListTile(
                  title: Text(name),
                  onTap: () => Navigator.pop(ctx, f['id']),
                );
              },
            ),
          ),
        ),
      );
      if (selected == null) return;
      setState(() => _isLoading = true);
      final backup = await _driveService.downloadBackup(selected);
      if (backup == null) throw Exception('download failed');

      // Automatic restore is not built yet; hand the file to the user
      // instead of pretending it was restored.
      await _backupService.shareBackup(backup);
    } catch (e) {
      if (mounted)
        _showError(
          _t(
            'Backup tidak bisa diunduh. Coba lagi.',
            "Couldn't download the backup. Try again.",
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The app shell already shows the title and back arrow.
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTile(title: _t('Buat backup', 'Create a backup')),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.download,
                  label: _t('Simpan ke file', 'Save to a file'),
                  subtitle: _t(
                    'File JSON yang bisa kamu simpan atau kirim',
                    'A JSON file you can keep or send',
                  ),
                  color: AppTheme.savingsColor,
                  onTap: _backupLocal,
                ),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.cloud_upload,
                  label: _t('Simpan ke Google Drive', 'Save to Google Drive'),
                  subtitle: _t(
                    'Disimpan di Drive akun Google kamu',
                    "Stored in your Google account's Drive",
                  ),
                  color: AppTheme.primaryColor,
                  onTap: _backupDrive,
                ),
                const SizedBox(height: 24),
                _SectionTile(title: _t('Backup di Drive', 'Backups in Drive')),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.cloud_download,
                  label: _t(
                    'Unduh backup dari Drive',
                    'Download a backup from Drive',
                  ),
                  subtitle: _t(
                    'Pilih backup lalu simpan sebagai file',
                    'Pick a backup and save it as a file',
                  ),
                  color: AppTheme.warningColor,
                  onTap: _restoreFromDrive,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warningColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _t(
                      'Backup berisi pemasukan, pengeluaran, tabungan, anggaran, hutang dan kategori. Data akun dan keluarga tidak ikut. File backup tidak dienkripsi, jadi simpan di tempat yang aman dan jangan dibagikan.',
                      "A backup holds income, spending, savings, budgets, debts and categories. Account and family data are not included. Backup files are not encrypted, so keep them somewhere safe and don't share them.",
                    ),
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
    );
  }
}
