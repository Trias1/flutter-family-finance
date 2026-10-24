import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

/// Danger zone at the bottom of Settings. Deletion itself runs on the server
/// (shared with the web app); this asks for confirmation and a fresh sign-in.
class DeleteAccountSection extends ConsumerWidget {
  const DeleteAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(localeProvider).languageCode == 'id';
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _DeleteAccountDialog(),
        ),
        icon: const Icon(
          Icons.delete_forever_outlined,
          color: AppTheme.errorColor,
        ),
        label: Text(
          id ? 'Hapus akun' : 'Delete account',
          style: const TextStyle(color: AppTheme.errorColor),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _id => ref.read(localeProvider).languageCode == 'id';
  String _t(String id, String en) => _id ? id : en;
  String get _word => _id ? 'HAPUS' : 'DELETE';

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  String _messageFor(String code) {
    switch (code) {
      case 'reauthRequired':
        return _t(
          'Demi keamanan, masuk ulang lalu coba lagi.',
          'For your safety, sign in again and retry.',
        );
      case 'rateLimited':
        return _t(
          'Terlalu sering. Coba lagi nanti.',
          'Too many attempts. Try again later.',
        );
      case 'cannotDeleteSuperadmin':
        return _t(
          'Akun superadmin tidak bisa dihapus dari aplikasi.',
          'Superadmin accounts cannot be deleted from the app.',
        );
      default:
        return _t(
          'Akun gagal dihapus. Cek koneksi lalu coba lagi.',
          "Couldn't delete the account. Check your connection and retry.",
        );
    }
  }

  Future<void> _delete() async {
    if (_confirm.text.trim().toUpperCase() != _word) {
      setState(
        () => _error = _t(
          'Ketik $_word untuk konfirmasi.',
          'Type $_word to confirm.',
        ),
      );
      return;
    }
    final ds = ref.read(firebaseAuthDataSourceProvider);
    final uid = ds.currentUser?.uid;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ds.reauthenticate(password: _password.text);
      final code = await ds.deleteAccount();
      if (code != null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = _messageFor(code);
          });
        }
        return;
      }
      // Forget this account's fingerprint setting on the phone too.
      final prefs = await SharedPreferences.getInstance();
      if (uid != null) {
        await prefs.remove('biometric_enabled_$uid');
        if (prefs.getString('biometric_last_uid') == uid) {
          await prefs.remove('biometric_last_uid');
        }
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.code == 'cancelled'
            ? null
            : (e.code == 'wrong-password' ||
                  e.code == 'invalid-credential' ||
                  e.code == 'invalid-login-credentials')
            ? _t('Password salah.', 'Wrong password.')
            : _messageFor('');
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _messageFor('');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesPassword = ref
        .read(firebaseAuthDataSourceProvider)
        .hasPasswordProvider;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AlertDialog(
      title: Text(_t('Hapus akun?', 'Delete account?')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                'Yang dihapus permanen: catatan pribadimu, profil, dan data perangkat. '
                    'Kalau kamu pemilik keluarga, kepemilikan pindah ke anggota lain; keluarga tanpa anggota lain ikut dihapus. '
                    'Catatan yang kamu tambahkan ke keluarga tetap ada untuk keluarga.',
                'Deleted for good: your personal records, profile and device data. '
                    'If you own a family, ownership passes to another member; a family with nobody else is deleted too. '
                    'Records you added to a family stay with that family.',
              ),
              style: TextStyle(color: muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: _t('Ketik $_word', 'Type $_word'),
              ),
            ),
            if (usesPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _t('Password', 'Password'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                _t(
                  'Kamu akan diminta memilih akun Google lagi untuk konfirmasi.',
                  'You will be asked to pick your Google account again to confirm.',
                ),
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(_t('Batal', 'Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
          onPressed: _busy ? null : _delete,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_t('Hapus permanen', 'Delete permanently')),
        ),
      ],
    );
  }
}
