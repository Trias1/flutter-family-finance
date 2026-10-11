import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/services/app_update_service.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

/// Signs out. With fingerprint unlock on, the Google session is kept so the
/// next sign-in can use the fingerprint, and auto sign-in is skipped once.
Future<void> signOutUser(BuildContext context, WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = prefs.getString('biometric_last_uid');
  final bioEnabled =
      uid != null && (prefs.getBool('biometric_enabled_$uid') ?? false);
  if (bioEnabled) await prefs.setBool('biometric_skip_auto_login', true);
  await ref
      .read(authNotifierProvider.notifier)
      .signOut(keepGoogleSession: bioEnabled);
  if (context.mounted) context.go('/login');
}

/// "Update available" with the release notes and a download button. A
/// required update cannot be dismissed.
Future<void> showAppUpdateDialog(
  BuildContext context,
  AppStrings strings,
  AppUpdateInfo update,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !update.forceUpdate,
    builder: (dialogContext) => PopScope(
      canPop: !update.forceUpdate,
      child: AlertDialog(
        title: Text(
          update.forceUpdate
              ? strings.requiredUpdateAvailable
              : strings.updateAvailable,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.latestVersion(update.latestVersionName)),
            const SizedBox(height: 8),
            Text(update.releaseNotes),
            const SizedBox(height: 12),
            Text(
              strings.updatePrivacyNote,
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (!update.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.later),
            ),
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(update.apkUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.download_rounded),
            label: Text(strings.updateNow),
          ),
        ],
      ),
    ),
  );
}
