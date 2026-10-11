import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:family_finance_manager/features/settings/presentation/widgets/profile_sections.dart';
import 'package:family_finance_manager/features/settings/presentation/pages/sessions_page.dart';
import 'package:family_finance_manager/features/settings/presentation/widgets/delete_account_section.dart';
import 'package:family_finance_manager/core/utils/validators.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/image_utils.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  /// False when shown as a bottom-nav tab: the shell already has an app bar.
  final bool showAppBar;

  const ProfilePage({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final familyAsync = ref.watch(familyProvider);
    final locale = Localizations.localeOf(context);
    final strings = AppStrings(locale);
    final id = locale.languageCode == 'id';
    final devices = ref.watch(sessionDevicesProvider).valueOrNull ?? const [];
    final activity = ref.watch(activityStatsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(strings.user),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            )
          : null,
      body: authState.when(
        data: (user) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Center(child: _ProfilePhoto(user: user)),
            const SizedBox(height: 12),
            Text(
              user?.name ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              user?.email ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            MenuGroup(
              children: [
                MenuRow(
                  icon: Icons.person_rounded,
                  color: MenuColors.blue,
                  title: id ? 'Akun' : 'Account',
                  subtitle: id
                      ? 'Nama, password, cara masuk'
                      : 'Name, password, sign-in method',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AccountPage(),
                    ),
                  ),
                ),
                MenuRow(
                  icon: Icons.family_restroom_rounded,
                  color: MenuColors.green,
                  title: strings.family,
                  subtitle: user?.familyId?.isNotEmpty == true
                      ? familyAsync.valueOrNull?.name ?? strings.family
                      : (id
                            ? 'Buat atau gabung keluarga'
                            : 'Create or join a family'),
                  onTap: () => context.push('/family'),
                ),
                MenuRow(
                  icon: Icons.local_fire_department_rounded,
                  color: MenuColors.orange,
                  title: id ? 'Aktivitas' : 'Activity',
                  subtitle: activitySummary(activity, id),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ActivityPage(),
                    ),
                  ),
                ),
                MenuRow(
                  icon: Icons.devices_rounded,
                  color: MenuColors.purple,
                  title: id ? 'Perangkat aktif' : 'Active sessions',
                  subtitle: id
                      ? 'HP & browser yang masuk ke akunmu'
                      : 'Phones and browsers signed in',
                  value: devices.isEmpty ? null : '${devices.length}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SessionsPage(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const ProfileMoreGroups(),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            Localizations.localeOf(context).languageCode == 'id'
                ? 'Profil belum bisa dimuat. Coba lagi nanti.'
                : "Couldn't load your profile. Try again later.",
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
  ) {
    final id = ref.read(localeProvider).languageCode == 'id';
    final nameController = TextEditingController(text: user?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id ? 'Ubah nama' : 'Change name'),
        content: TextField(
          controller: nameController,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: id ? 'Nama' : 'Name',
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(id ? 'Batal' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final err = await ref
                  .read(authNotifierProvider.notifier)
                  .updateProfile(name: nameController.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: Text(id ? 'Simpan' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final id = ref.read(localeProvider).languageCode == 'id';
    final hasPassword =
        FirebaseAuth.instance.currentUser?.providerData.any(
          (p) => p.providerId == 'password',
        ) ??
        false;
    if (!hasPassword) {
      // Google-only accounts have no app password to change.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(id ? 'Akun Google' : 'Google account'),
          content: Text(
            id
                ? 'Kamu masuk dengan Google, jadi tidak ada password khusus untuk aplikasi ini. Keamanan akunmu diatur di akun Google.'
                : 'You sign in with Google, so this app has no separate password. Your account security is managed in your Google account.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    var busy = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(id ? 'Ubah password' : 'Change password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: id ? 'Password saat ini' : 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? (id
                            ? 'Masukkan password saat ini'
                            : 'Enter your current password')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: id ? 'Password baru' : 'New password',
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (v) {
                    if (v != null && v == currentController.text) {
                      return id
                          ? 'Password baru harus beda'
                          : 'Choose a different password';
                    }
                    return Validators.newPassword(v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: id
                        ? 'Ulangi password baru'
                        : 'Repeat new password',
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (v) => v != newController.text
                      ? (id ? 'Password tidak sama' : 'Passwords do not match')
                      : null,
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text(id ? 'Batal' : 'Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      final err = await ref
                          .read(authNotifierProvider.notifier)
                          .changePassword(
                            newController.text,
                            currentPassword: currentController.text,
                          );
                      if (!ctx.mounted) return;
                      if (err != null) {
                        // Stay open so the user can correct and retry.
                        setState(() {
                          busy = false;
                          error = err;
                        });
                        return;
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            id
                                ? 'Password berhasil diubah'
                                : 'Password changed',
                          ),
                          backgroundColor: AppTheme.incomeColor,
                        ),
                      );
                    },
              child: Text(id ? 'Simpan' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name, email, password and how the account signs in.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  /// New email + current password; Firebase mails a link to the new address
  /// and the change happens when it is opened.
  Future<void> _changeEmail(BuildContext context, WidgetRef ref) async {
    final id = ref.read(localeProvider).languageCode == 'id';
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? error;
    var busy = false;
    final sentTo = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(id ? 'Ganti email' : 'Change email'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id
                      ? 'Kami kirim link ke email baru. Email baru dipakai setelah link itu diklik; sampai saat itu email lama tetap berlaku.'
                      : "We'll send a link to the new address. It takes over once the link is opened; until then the old one still works.",
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: id ? 'Email baru' : 'New email',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  enabled: !busy,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: id ? 'Password sekarang' : 'Current password',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text(id ? 'Batal' : 'Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (Validators.email(email) != null) {
                        setState(
                          () => error = id
                              ? 'Format email tidak valid.'
                              : 'That email address is not valid.',
                        );
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(firebaseAuthDataSourceProvider)
                            .requestEmailChange(email, passCtrl.text);
                        if (ctx.mounted) Navigator.pop(ctx, email);
                      } on FirebaseAuthException catch (e) {
                        setState(() {
                          busy = false;
                          error = switch (e.code) {
                            'wrong-password' ||
                            'invalid-credential' ||
                            'invalid-login-credentials' =>
                              id ? 'Password salah.' : 'Wrong password.',
                            'email-already-in-use' =>
                              id
                                  ? 'Email itu sudah dipakai akun lain.'
                                  : 'That email belongs to another account.',
                            'invalid-email' =>
                              id
                                  ? 'Format email tidak valid.'
                                  : 'That email address is not valid.',
                            'too-many-requests' =>
                              id
                                  ? 'Terlalu sering. Coba lagi nanti.'
                                  : 'Too many attempts. Try again later.',
                            _ =>
                              id
                                  ? 'Gagal mengirim link. Coba lagi nanti.'
                                  : "Couldn't send the link. Try again later.",
                          };
                        });
                      } catch (_) {
                        setState(() {
                          busy = false;
                          error = id
                              ? 'Gagal mengirim link. Cek koneksi lalu coba lagi.'
                              : "Couldn't send the link. Check your connection.";
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(id ? 'Kirim link' : 'Send link'),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
    passCtrl.dispose();
    if (sentTo == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id ? 'Cek email baru' : 'Check your new inbox'),
        content: Text(
          id
              ? 'Link sudah dikirim ke $sentTo. Buka link itu untuk menyelesaikan. Setelahnya kamu mungkin diminta masuk lagi dengan email baru.'
              : 'We sent a link to $sentTo. Open it to finish. You may be asked to sign in again with the new email afterwards.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(localeProvider).languageCode == 'id';
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final usesPassword = ref
        .read(firebaseAuthDataSourceProvider)
        .hasPasswordProvider;
    const profile = ProfilePage();
    return Scaffold(
      appBar: AppBar(title: Text(id ? 'Akun' : 'Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          MenuGroup(
            label: id ? 'Profil' : 'Profile',
            children: [
              MenuRow(
                icon: Icons.badge_rounded,
                color: MenuColors.blue,
                title: id ? 'Nama' : 'Name',
                subtitle: user?.name ?? '',
                onTap: () => profile._showEditProfileDialog(context, ref, user),
              ),
              MenuRow(
                icon: Icons.alternate_email_rounded,
                color: MenuColors.teal,
                title: 'Email',
                subtitle: usesPassword
                    ? user?.email ?? ''
                    : '${user?.email ?? ''} · ${id ? 'mengikuti akun Google' : 'from your Google account'}',
                onTap: usesPassword ? () => _changeEmail(context, ref) : null,
              ),
              if (usesPassword)
                MenuRow(
                  icon: Icons.lock_rounded,
                  color: MenuColors.orange,
                  title: id ? 'Ubah password' : 'Change password',
                  onTap: () => profile._showChangePasswordDialog(context, ref),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const AccountInfoGroup(),
          const SizedBox(height: 32),
          const DeleteAccountSection(),
        ],
      ),
    );
  }
}

class _ProfilePhoto extends ConsumerWidget {
  final dynamic user;
  const _ProfilePhoto({required this.user});

  Future<void> _pickAndUploadPhoto(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final base64Str = base64Encode(bytes);
      final photoUrl = 'data:image/jpeg;base64,$base64Str';
      final err = await ref
          .read(authNotifierProvider.notifier)
          .updateProfile(photoUrl: photoUrl);
      if (context.mounted && err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'id'
                  ? 'Foto gagal diunggah. Coba foto lain.'
                  : "Couldn't upload the photo. Try another one.",
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _pickAndUploadPhoto(context, ref),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            backgroundImage: getAvatarProvider(user?.photoUrl),
            child: user?.photoUrl == null
                ? Text(
                    user?.name.isNotEmpty == true
                        ? user.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 36,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
