import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

/// How long the app may sit in the background before it locks again.
const _relockAfter = Duration(minutes: 1);

/// True when a signed-in user turned fingerprint on for this device.
Future<bool> fingerprintLockEnabled() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('biometric_enabled_$uid') ?? false;
}

/// Whether the app is currently hidden behind the fingerprint lock.
/// main() overrides the initial value so the first frame is already locked
/// and no finance data flashes on screen.
final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>(
  (ref) => AppLockNotifier(false),
);

class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier(super.locked);

  bool _authenticating = false;
  // Set when the lock only covers the app while it is in the background.
  bool _coverOnly = false;

  /// Hides the app as soon as it leaves the screen, so finance data is not
  /// in the recent-apps preview or visible behind the fingerprint prompt.
  Future<void> coverIfEnabled() async {
    if (state || !await fingerprintLockEnabled() || !mounted) return;
    _coverOnly = true;
    state = true;
  }

  /// Back after a short trip away: drop the cover without asking again.
  /// Returns false when the app stays locked and needs a fingerprint.
  bool resume({required bool longAway}) {
    if (!state) return true;
    if (_coverOnly && !longAway) {
      _coverOnly = false;
      state = false;
      return true;
    }
    _coverOnly = false;
    return false;
  }

  void clear() {
    _coverOnly = false;
    state = false;
  }

  /// Returns true when unlocked. Cancelling keeps the app locked.
  Future<bool> unlock({required String reason}) async {
    if (_authenticating) return false;
    _authenticating = true;
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) state = false;
      return ok;
    } catch (_) {
      return false;
    } finally {
      _authenticating = false;
    }
  }
}

/// Covers the whole app with a lock screen while [appLockProvider] is true,
/// and locks again after the app has been in the background for a while.
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Not `inactive`: that also fires for the fingerprint prompt itself,
    // permission dialogs and the notification shade.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (_backgroundedAt == null) {
        _backgroundedAt = DateTime.now();
        ref.read(appLockProvider.notifier).coverIfEnabled();
      }
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since == null) return;
      ref
          .read(appLockProvider.notifier)
          .resume(longAway: DateTime.now().difference(since) >= _relockAfter);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Signing out (here or elsewhere) always drops the lock.
    ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull == null) ref.read(appLockProvider.notifier).clear();
    });
    final locked = ref.watch(appLockProvider);
    return Stack(
      children: [
        // Keep the app mounted but unreachable while locked.
        ExcludeSemantics(
          excluding: locked,
          child: AbsorbPointer(absorbing: locked, child: widget.child),
        ),
        if (locked) const Positioned.fill(child: _LockScreen()),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen>
    with WidgetsBindingObserver {
  bool _failed = false;

  bool get _isId => ref.read(localeProvider).languageCode == 'id';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Only prompt while the app is on screen; a cover added on the way to
    // the background waits for the user to come back.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // AppLockGate handles resume first and may already have dropped the lock.
    if (state == AppLifecycleState.resumed && ref.read(appLockProvider)) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    final ok = await ref
        .read(appLockProvider.notifier)
        .unlock(
          reason: _isId
              ? 'Scan sidik jari untuk membuka aplikasi'
              : 'Scan your fingerprint to open the app',
        );
    if (!ok && mounted) setState(() => _failed = true);
  }

  Future<void> _useAnotherAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_skip_auto_login', true);
    await ref.read(authNotifierProvider.notifier).signOut();
    ref.read(appLockProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isId ? 'Aplikasi terkunci' : 'App locked',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _failed
                    ? (isId
                          ? 'Sidik jari belum cocok atau dibatalkan. Coba lagi.'
                          : 'Fingerprint not recognised or cancelled. Try again.')
                    : (isId
                          ? 'Buka dengan sidik jari untuk melihat data keuanganmu.'
                          : 'Unlock with your fingerprint to see your finances.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(isId ? 'Buka dengan sidik jari' : 'Unlock'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _useAnotherAccount,
                child: Text(
                  isId
                      ? 'Keluar dan masuk dengan akun lain'
                      : 'Sign out and use another account',
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
