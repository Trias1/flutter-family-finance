import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _ProfilePhoto(user: user),
              const SizedBox(height: 24),
              _InfoTile(
                icon: Icons.person_outline,
                label: id ? 'Nama' : 'Name',
                value: user?.name ?? '',
              ),
              const SizedBox(height: 8),
              _InfoTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: user?.email ?? '',
              ),
              const SizedBox(height: 8),
              // Always reachable, so users without a family can create or join one.
              _InfoTile(
                icon: Icons.family_restroom_rounded,
                label: strings.family,
                value: user?.familyId?.isNotEmpty == true
                    ? familyAsync.when(
                        data: (family) => family?.name ?? strings.family,
                        loading: () => '...',
                        error: (_, __) => strings.family,
                      )
                    : (locale.languageCode == 'id'
                          ? 'Buat atau gabung keluarga'
                          : 'Create or join a family'),
                onTap: () => context.push('/family'),
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: id ? 'Edit profil' : 'Edit profile'),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.edit_rounded,
                label: id ? 'Ubah nama' : 'Change name',
                color: AppTheme.primaryColor,
                onTap: () => _showEditProfileDialog(context, ref, user),
              ),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.lock_outline_rounded,
                label: id ? 'Ubah password' : 'Change password',
                color: AppTheme.warningColor,
                onTap: () => _showChangePasswordDialog(context, ref),
              ),
            ],
          ),
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (onTap != null) ...[
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return tile;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: tile,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
