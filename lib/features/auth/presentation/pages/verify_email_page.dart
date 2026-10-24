import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

/// Email/password accounts land here until they open the verification link.
/// Firestore rules refuse finance and family data until then, so this is
/// not just a screen: it mirrors what the server enforces.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage>
    with WidgetsBindingObserver {
  static const _resendCooldown = 60;

  bool _checking = false;
  String? _message;
  bool _messageIsError = false;
  int _cooldown = 0;
  Timer? _timer;

  bool get _id => ref.read(localeProvider).languageCode == 'id';
  String _t(String id, String en) => _id ? id : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The cached user may be stale (e.g. verified on another device).
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Coming back from the email app: check quietly.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  Future<void> _check({bool silent = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _checking) return;
    setState(() => _checking = true);
    try {
      // Refresh the ID token first so Firestore sees email_verified = true,
      // then reload, which also tells the router to move on.
      await user.getIdToken(true);
      await user.reload();
      final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (!verified && !silent && mounted) {
        _show(
          _t(
            'Email belum terverifikasi. Buka link di email kamu dulu.',
            'Not verified yet. Open the link in your email first.',
          ),
          error: true,
        );
      }
    } catch (_) {
      if (!silent && mounted) {
        _show(
          _t('Tidak bisa mengecek. Cek koneksi internet.', "Couldn't check. Check your connection."),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cooldown > 0) return;
    try {
      await user.sendEmailVerification();
      _show(_t('Email verifikasi dikirim ulang.', 'Verification email sent again.'));
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      _show(
        e.code == 'too-many-requests'
            ? _t('Terlalu sering. Tunggu beberapa menit lalu coba lagi.', 'Too many attempts. Wait a few minutes and try again.')
            : _t('Email tidak terkirim. Coba lagi nanti.', "Couldn't send the email. Try again later."),
        error: true,
      );
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = _resendCooldown);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown--);
    });
  }

  void _show(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _messageIsError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final scheme = Theme.of(context).colorScheme;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 32,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _t('Cek email kamu', 'Check your email'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _t(
                        'Kami mengirim link verifikasi ke ',
                        'We sent a verification link to ',
                      ),
                    ),
                    TextSpan(
                      text: email,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: _t(
                        '. Buka link itu, lalu kembali ke aplikasi ini. Kalau tidak ada, cek folder Spam.',
                        '. Open it, then come back to this app. If you cannot find it, check your Spam folder.',
                      ),
                    ),
                  ],
                ),
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  'Data keuangan baru bisa dibuka setelah email terverifikasi, supaya akun tidak bisa dibuat dengan email orang lain.',
                  'Your finances open once the email is verified, so nobody can sign up with an address that is not theirs.',
                ),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _messageIsError
                        ? AppTheme.errorColor
                        : AppTheme.incomeColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _checking ? null : () => _check(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_t('Saya sudah verifikasi', "I've verified")),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cooldown > 0 ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _cooldown > 0
                        ? _t('Kirim ulang ($_cooldown)', 'Resend ($_cooldown)')
                        : _t('Kirim ulang email', 'Resend email'),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).signOut(),
                  child: Text(
                    _t('Keluar dan pakai email lain', 'Sign out and use another email'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
