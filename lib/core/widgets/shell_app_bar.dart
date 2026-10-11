import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/theme/theme_provider.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

const _daysId = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
const _daysEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthsId = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
const _monthsEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Sabtu, 11 Okt" / "Saturday, 11 Oct".
String shortToday(DateTime d, bool isId) =>
    '${(isId ? _daysId : _daysEn)[d.weekday - 1]}, ${d.day} ${(isId ? _monthsId : _monthsEn)[d.month - 1]}';

/// Greeting by the hour of the day.
String greeting(DateTime d, bool isId) {
  final h = d.hour;
  if (isId) {
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Left-aligned title for the shell. On Dashboard it greets the user and
/// says which books are open (family or personal) and today's date.
class ShellTitle extends ConsumerWidget {
  final String title;
  final bool greet;
  const ShellTitle({super.key, required this.title, this.greet = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (!greet) {
      return Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      );
    }
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final family = ref.watch(familyProvider).valueOrNull;
    final now = DateTime.now();
    final first = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final books = (user?.familyId?.isNotEmpty ?? false)
        ? (family?.name ?? (isId ? 'Keluarga' : 'Family'))
        : (isId ? 'Pribadi' : 'Personal');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          first.isEmpty
              ? greeting(now, isId)
              : '${greeting(now, isId)}, $first',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          '$books · ${shortToday(now, isId)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The ⋮ menu at the top right, like WhatsApp's.
class ShellMenu extends ConsumerWidget {
  const ShellMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(ref.watch(localeProvider));
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;

    // Menu items run after the menu closes.
    void later(VoidCallback action) =>
        Future<void>.delayed(Duration.zero, action);

    Future<void> logout() async {
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

    PopupMenuItem<void> item(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) => PopupMenuItem<void>(
      onTap: () => later(onTap),
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );

    return PopupMenuButton<void>(
      tooltip: isId ? 'Menu lainnya' : 'More options',
      icon: const Icon(Icons.more_vert_rounded),
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        item(
          Icons.family_restroom_rounded,
          isId ? 'Keluarga' : 'Family',
          () => context.mounted ? context.push('/family') : null,
        ),
        item(
          Icons.settings_outlined,
          strings.settings,
          () => context.mounted ? context.push('/settings') : null,
        ),
        item(
          dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          dark
              ? (isId ? 'Mode terang' : 'Light mode')
              : (isId ? 'Mode gelap' : 'Dark mode'),
          () => ref.read(themeModeProvider.notifier).toggle(),
        ),
        const PopupMenuDivider(),
        item(
          Icons.logout_rounded,
          strings.logout,
          logout,
          color: AppTheme.errorColor,
        ),
      ],
    );
  }
}
