import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/validators.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/widgets/brand_mark.dart';
import 'package:family_finance_manager/core/services/session_service.dart';

/// Picks the Indonesian or English text for the app's current language.
String _tr(BuildContext context, String id, String en) =>
    Localizations.localeOf(context).languageCode == 'id' ? id : en;

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // "Remember me": the email is kept by the app; the password goes to the
  // phone's password manager (Google), never into the app's storage.
  bool _remember = false;
  static const _rememberKey = 'login_remembered_email';
  bool _biometricBusy = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _checkBiometricAutoLogin();
    _explainRemoteSignOut();
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_rememberKey);
    if (email == null || !mounted) return;
    setState(() {
      _remember = true;
      if (_emailController.text.isEmpty) _emailController.text = email;
    });
  }

  /// After "Sign out this device" from another phone or browser.
  Future<void> _explainRemoteSignOut() async {
    if (!await SessionService.takeRemoteSignOutNotice() || !mounted) return;
    final isId = Localizations.localeOf(context).languageCode == 'id';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          isId
              ? 'Kamu dikeluarkan dari perangkat ini lewat perangkat lain. Masuk lagi kalau ini memang perangkatmu.'
              : 'You were signed out of this device from another one. Sign in again if this is your device.',
        ),
      ),
    );
  }

  /// The fingerprint prompt on app start now lives in AppLockGate; this page
  /// only clears leftovers from older versions.
  Future<void> _checkBiometricAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    // Older versions kept the password in plain text for biometric re-login.
    await prefs.remove('last_password');
    await prefs.setBool('biometric_skip_auto_login', false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authNotifierProvider.notifier);
    final error = await notifier.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (mounted && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(error, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
      return;
    }
    if (mounted && error == null) {
      final prefs = await SharedPreferences.getInstance();
      final email = _emailController.text.trim();
      await prefs.setString('last_email', email);
      if (_remember) {
        await prefs.setString(_rememberKey, email);
      } else {
        await prefs.remove(_rememberKey);
      }
      // Android offers to save the email and password in its password
      // manager, which fills them in next time.
      TextInput.finishAutofillContext(shouldSave: _remember);
      if (!mounted) return;
      final firebaseUser = ref.read(firebaseAuthDataSourceProvider).currentUser;
      if (firebaseUser != null) {
        await prefs.setString('biometric_last_uid', firebaseUser.uid);
      }
      await prefs.setString('last_login_method', 'email');
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  /// Biometrics unlock an existing session; they never replace the password.
  /// After an explicit logout, email accounts must type their password again.
  /// Google accounts can be restored silently because no secret is stored.
  Future<void> _loginWithBiometric() async {
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);
    try {
      final authenticated = await LocalAuthentication().authenticate(
        localizedReason: _tr(
          context,
          'Scan sidik jari untuk masuk',
          'Scan your fingerprint to sign in',
        ),
      );
      if (!authenticated || !mounted) return;

      var firebaseUser = ref.read(firebaseAuthDataSourceProvider).currentUser;
      if (firebaseUser == null) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('last_login_method') == 'google') {
          final account = await GoogleSignIn().signInSilently();
          if (account != null) {
            final auth = await account.authentication;
            await FirebaseAuth.instance.signInWithCredential(
              GoogleAuthProvider.credential(
                accessToken: auth.accessToken,
                idToken: auth.idToken,
              ),
            );
            firebaseUser = FirebaseAuth.instance.currentUser;
            if (firebaseUser != null) {
              await prefs.setString('biometric_last_uid', firebaseUser.uid);
            }
          }
        }
      }

      if (!mounted) return;
      if (firebaseUser == null) {
        _showSnack(
          _tr(
            context,
            'Sesi sudah berakhir. Masuk sekali lagi dengan email dan password atau Google.',
            'Your session has ended. Sign in again with email and password or Google.',
          ),
          AppTheme.warningColor,
        );
        return;
      }
      await ref
          .read(authNotifierProvider.notifier)
          .restoreSession(firebaseUser.uid);
    } catch (_) {
      if (mounted)
        _showSnack(
          _tr(
            context,
            'Masuk dengan sidik jari gagal. Coba lagi.',
            'Fingerprint sign-in failed. Try again.',
          ),
          AppTheme.errorColor,
        );
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    final error = await notifier.signInWithGoogle();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(error, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_login_method', 'google');
    if (!mounted) return;
    final firebaseUser = ref.read(firebaseAuthDataSourceProvider).currentUser;
    if (firebaseUser != null) {
      await prefs.setString('biometric_last_uid', firebaseUser.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: size.width,
              height: size.height * 0.35,
              decoration: BoxDecoration(
                // Solid colour: gradients made the app look generic.
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: const BrandMark(size: 46),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Family Finance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _tr(
                          context,
                          'Kelola keuangan keluarga dengan bijak',
                          "Your family's money, in one place",
                        ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Transform.translate(
                    offset: const Offset(0, -30),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          onDisposeAction: AutofillContextAction.cancel,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tr(context, 'Masuk', 'Sign in'),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _tr(
                                  context,
                                  'Masuk ke akunmu',
                                  'Sign in to your account',
                                ),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _emailController,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: _tr(
                                    context,
                                    'Masukkan email',
                                    'Enter your email',
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppTheme.errorColor,
                                      width: 1,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppTheme.errorColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: Validators.email,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                autofillHints: const [AutofillHints.password],
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: _tr(
                                    context,
                                    'Password',
                                    'Password',
                                  ),
                                  hintText: _tr(
                                    context,
                                    'Masukkan password',
                                    'Enter your password',
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outlined,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppTheme.errorColor,
                                      width: 1,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppTheme.errorColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: Validators.password,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => setState(
                                        () => _remember = !_remember,
                                      ),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: _remember,
                                            onChanged: (v) => setState(
                                              () => _remember = v ?? false,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          Flexible(
                                            child: Text(
                                              _tr(
                                                context,
                                                'Ingat saya',
                                                'Remember me',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        context.push('/forgot-password'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                    child: Text(
                                      _tr(
                                        context,
                                        'Lupa password?',
                                        'Forgot password?',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _tr(context, 'Masuk', 'Sign in'),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      _tr(context, 'atau', 'or'),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : _loginWithGoogle,
                                  icon: Image.asset(
                                    'assets/google.png',
                                    height: 20,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.g_mobiledata,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  label: Text(
                                    _tr(
                                      context,
                                      'Lanjutkan dengan Google',
                                      'Continue with Google',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    side: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              FutureBuilder<bool>(
                                future: Future.wait([
                                  LocalAuthentication().canCheckBiometrics,
                                  SharedPreferences.getInstance().then((
                                    prefs,
                                  ) async {
                                    final uid =
                                        FirebaseAuth.instance.currentUser?.uid;
                                    final lastUid =
                                        uid ??
                                        prefs.getString('biometric_last_uid');
                                    final key = lastUid != null
                                        ? 'biometric_enabled_$lastUid'
                                        : 'biometric_enabled';
                                    return prefs.getBool(key) ?? false;
                                  }),
                                ]).then((results) => results[0] && results[1]),
                                builder: (context, snapshot) {
                                  if (snapshot.data != true)
                                    return const SizedBox.shrink();
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton.icon(
                                      onPressed: isLoading
                                          ? null
                                          : _loginWithBiometric,
                                      icon: const Icon(
                                        Icons.fingerprint,
                                        color: AppTheme.savingsColor,
                                      ),
                                      label: Text(
                                        _tr(
                                          context,
                                          'Masuk dengan sidik jari',
                                          'Sign in with fingerprint',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.savingsColor,
                                        side: BorderSide(
                                          color: AppTheme.savingsColor
                                              .withValues(alpha: 0.3),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _tr(
                        context,
                        'Belum punya akun? ',
                        "Don't have an account? ",
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text(
                        _tr(context, 'Daftar', 'Sign up'),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
