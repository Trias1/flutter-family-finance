import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/services/backup_service.dart';
import 'package:family_finance_manager/core/services/drive_backup_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class _SectionTile extends StatelessWidget {
  final String title;
  const _SectionTile({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
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

  Future<void> _backupLocal() async {
    setState(() => _isLoading = true);
    try {
      final familyId = ref.read(financeScopeIdProvider);
      final ds = ref.read(firestoreDataSourceProvider);
      final backup = await _backupService.collectData(ds, familyId);
      await _backupService.shareBackup(backup);
    } catch (e) {
      if (mounted) _showError('Gagal backup: $e');
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
              success ? 'Backup Drive berhasil' : 'Gagal backup Drive',
            ),
            backgroundColor:
                success ? AppTheme.incomeColor : AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Gagal backup Drive: $e');
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
        if (mounted) _showError('Tidak ada backup di Drive');
        return;
      }
      if (!mounted) return;
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pilih Backup'),
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
      if (backup == null) throw Exception('Gagal download backup');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restore: ${backup.createdAt.day}/${backup.createdAt.month}/${backup.createdAt.year} - ${backup.data.length} item. Restore manual via Firestore console.',
            ),
            backgroundColor: AppTheme.incomeColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Gagal restore: $e');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTile(title: 'Backup Data'),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.download,
                  label: 'Backup ke File',
                  subtitle: 'Simpan & share sebagai file JSON',
                  color: AppTheme.savingsColor,
                  onTap: _backupLocal,
                ),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.cloud_upload,
                  label: 'Backup ke Google Drive',
                  subtitle: 'Upload ke Drive',
                  color: AppTheme.primaryColor,
                  onTap: _backupDrive,
                ),
                const SizedBox(height: 24),
                _SectionTile(title: 'Restore Data'),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.cloud_download,
                  label: 'Restore dari Drive',
                  subtitle: 'Pilih backup dari Drive',
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
                  child: const Text(
                    'Backup mencakup pemasukan, pengeluaran, tabungan, anggaran, dompet, wishlist. Data akun & keluarga tidak termasuk.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
    );
  }
}
