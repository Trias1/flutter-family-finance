import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_finance_manager/core/biometric/biometric_provider.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/app_update_service.dart';
import 'package:family_finance_manager/core/services/currency_provider.dart';
import 'package:family_finance_manager/core/services/notification_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/theme/theme_provider.dart';
import 'package:family_finance_manager/data/models/currency_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final strings = AppStrings(locale);
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      data: (user) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _SectionTitle(title: 'Bahasa / Language'),
            const SizedBox(height: 8),
            _LanguagePicker(),
            const SizedBox(height: 12),
            _CurrencyPicker(),
            const SizedBox(height: 16),
            _SectionTitle(title: strings.security),
            const SizedBox(height: 8),
            _BiometricToggle(),
            const SizedBox(height: 16),
            _ActionButton(
              icon: Icons.category_rounded,
              label: strings.manageCategories,
              color: AppTheme.primaryColor,
              onTap: () => context.push('/categories'),
            ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: Icons.backup_rounded,
              label: strings.backupRestore,
              color: AppTheme.savingsColor,
              onTap: () => context.push('/backup'),
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: strings.notifications),
            const SizedBox(height: 8),
            const _NotificationToggle(),
            const SizedBox(height: 16),
            _SectionTitle(title: strings.appearance),
            const SizedBox(height: 8),
            _DarkModeToggle(),
            const SizedBox(height: 12),
            _ThemePresetPicker(),
            const SizedBox(height: 16),
            _ActionButton(
              icon: Icons.privacy_tip_rounded,
              label: strings.privacySecurity,
              color: AppTheme.primaryColor,
              onTap: () => context.push('/privacy-security'),
            ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: Icons.menu_book_rounded,
              label: strings.completeGuide,
              color: AppTheme.savingsColor,
              onTap: () async {
                final lang = locale.languageCode == 'id' ? 'id' : 'en';
                final uri = Uri.parse(
                  'https://family-finance.tzm.web.id/$lang/guide',
                );
                // canLaunchUrl needs a <queries> entry on Android 11+ and
                // silently said "no"; just try and report a failure.
                var opened = false;
                try {
                  opened = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {}
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.guideOpenFailed)),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final uid = prefs.getString('biometric_last_uid');
                  final bioEnabled =
                      uid != null &&
                      (prefs.getBool('biometric_enabled_$uid') ?? false);
                  if (bioEnabled)
                    await prefs.setBool('biometric_skip_auto_login', true);
                  await ref
                      .read(authNotifierProvider.notifier)
                      .signOut(keepGoogleSession: bioEnabled);
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.errorColor,
                ),
                label: Text(
                  strings.logout,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _AppVersionText(),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _AppVersionText extends StatelessWidget {
  const _AppVersionText();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDeviceInfo>(
      future: AppUpdateService().getCurrentDeviceInfo(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final text = info == null
            ? 'Family Finance'
            : 'Family Finance v${info.appVersionName}+${info.appVersionCode}';
        return Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        );
      },
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

class _DarkModeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
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
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 22,
          ),
        ),
        title: Text(
          AppStrings(ref.watch(localeProvider)).darkMode,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        trailing: Switch(
          value: isDark,
          onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ThemePresetPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themePresetProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings(ref.watch(localeProvider)).themeColor,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...AppTheme.presets.map(
            (preset) => _ThemePresetTile(
              preset: preset,
              selected: preset.id == selected.id,
              onTap: () =>
                  ref.read(themePresetProvider.notifier).setPreset(preset),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePresetTile extends StatelessWidget {
  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _ThemePresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.08)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Row(
                children: [
                  _ThemeDot(color: preset.primary),
                  _ThemeDot(color: preset.background),
                  _ThemeDot(color: preset.accent),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Localizations.localeOf(context).languageCode == 'id'
                          ? preset.vibe
                          : preset.vibeEn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeDot extends StatelessWidget {
  final Color color;
  const _ThemeDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}

class _BiometricToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(biometricEnabledProvider);
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
            color: AppTheme.savingsColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.fingerprint,
            color: AppTheme.savingsColor,
            size: 22,
          ),
        ),
        title: Text(
          AppStrings(ref.watch(localeProvider)).fingerprint,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          isEnabled
              ? AppStrings(ref.watch(localeProvider)).on
              : AppStrings(ref.watch(localeProvider)).off,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: (_) async {
            final err = await ref
                .read(biometricEnabledProvider.notifier)
                .toggle();
            if (context.mounted && err != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(err),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          activeColor: AppTheme.savingsColor,
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

class _LanguagePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isEnglish = locale.languageCode == 'en';
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
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.language, color: AppTheme.primaryColor, size: 22),
        ),
        title: const Text(
          'Bahasa / Language',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          isEnglish ? 'English' : 'Indonesia',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('EN')),
            ButtonSegment(value: 'id', label: Text('ID')),
          ],
          selected: {isEnglish ? 'en' : 'id'},
          onSelectionChanged: (sel) {
            final code = sel.first;
            ref
                .read(localeProvider.notifier)
                .setLocale(
                  code == 'id'
                      ? const Locale('id', 'ID')
                      : const Locale('en', 'US'),
                );
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

class _NotificationToggle extends ConsumerWidget {
  const _NotificationToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(notificationEnabledProvider);
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
            color: AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: AppTheme.warningColor,
            size: 22,
          ),
        ),
        title: Text(
          AppStrings(ref.watch(localeProvider)).notifications,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          isEnabled
              ? AppStrings(ref.watch(localeProvider)).on
              : AppStrings(ref.watch(localeProvider)).off,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: (_) =>
              ref.read(notificationEnabledProvider.notifier).toggle(),
          activeColor: AppTheme.warningColor,
        ),
      ),
    );
  }
}

class _CurrencyPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyAsync = ref.watch(currencyProvider);
    return currencyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (current) => Container(
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.incomeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.attach_money,
              color: AppTheme.incomeColor,
              size: 22,
            ),
          ),
          title: Text(
            AppStrings(ref.watch(localeProvider)).currency,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          subtitle: Text(
            '${current.symbol} - ${current.code}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: PopupMenuButton<CurrencyModel>(
            onSelected: (c) async {
              final err = await ref
                  .read(currencyProvider.notifier)
                  .setCurrency(
                    c,
                    isId: ref.read(localeProvider).languageCode == 'id',
                  );
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(err)));
              }
            },
            itemBuilder: (_) => CurrencyModel.supported
                .map(
                  (c) => PopupMenuItem(
                    value: c,
                    child: Text('${c.symbol} ${c.code} - ${c.name}'),
                  ),
                )
                .toList(),
            child: Container(
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
          ),
        ),
      ),
    );
  }
}
