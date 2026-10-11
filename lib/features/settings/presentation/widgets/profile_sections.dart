import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/app_update_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/widgets/account_actions.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';

// Building blocks for the Profile tab in a Telegram-like layout: grouped
// rows with coloured icon tiles, each opening its own page.

const _months = {
  true: [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ],
  false: [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ],
};

String _monthYear(DateTime d, bool isId) =>
    '${_months[isId]![d.month - 1]} ${d.year}';

/// Days in a row, up to today, with at least one transaction recorded. A
/// streak still counts when today has nothing yet but yesterday does.
int recordingStreak(Iterable<DateTime> recordedAt, DateTime today) {
  final days = {for (final d in recordedAt) DateTime(d.year, d.month, d.day)};
  var day = DateTime(today.year, today.month, today.day);
  if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// Tile colours, one per row, like Telegram's settings list.
class MenuColors {
  static const blue = Color(0xFF3D7BD9);
  static const green = Color(0xFF3FA866);
  static const orange = Color(0xFFE8863A);
  static const purple = Color(0xFF8A63D2);
  static const grey = Color(0xFF8E8E93);
  static const teal = Color(0xFF2FA7A0);
  static const red = Color(0xFFE0534A);
  static const pink = Color(0xFFD9467A);
}

/// Group background: a step lighter than the page in dark mode so groups
/// stand out, plain surface in light mode.
Color groupColor(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Theme.of(context).brightness == Brightness.dark
      ? scheme.surfaceContainerHigh
      : scheme.surface;
}

/// A rounded group of rows with an optional coloured label above it.
class MenuGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;
  final String? footer;
  const MenuGroup({super.key, this.label, required this.children, this.footer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, indent: 60));
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: groupColor(context),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              footer!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// One row: coloured icon tile, title, small grey subtitle, then a value or
/// a chevron.
class MenuRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final bool danger;
  final VoidCallback? onTap;
  const MenuRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: danger ? AppTheme.errorColor : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  value!,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            if (onTap != null && !danger)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// How the user signs in, whether the email is verified, and since when.
class AccountInfoGroup extends ConsumerWidget {
  const AccountInfoGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final auth = FirebaseAuth.instance.currentUser;
    if (user == null || auth == null) return const SizedBox.shrink();
    final providers = auth.providerData.map((p) => p.providerId).toSet();
    final google = providers.contains('google.com');
    final password = providers.contains('password');
    final method = [
      if (google) 'Google',
      if (password) 'Email & password',
    ].join(' + ');
    final verified = auth.emailVerified || google;

    return MenuGroup(
      label: isId ? 'Keamanan akun' : 'Account security',
      children: [
        MenuRow(
          icon: Icons.key_rounded,
          color: MenuColors.grey,
          title: isId ? 'Cara masuk' : 'Signs in with',
          subtitle: method.isEmpty ? '-' : method,
        ),
        MenuRow(
          icon: verified ? Icons.verified_rounded : Icons.mark_email_unread,
          color: verified ? MenuColors.green : MenuColors.orange,
          title: verified
              ? (isId ? 'Email terverifikasi' : 'Email verified')
              : (isId ? 'Email belum terverifikasi' : 'Email not verified'),
          subtitle: user.email,
        ),
        MenuRow(
          icon: Icons.event_available_rounded,
          color: MenuColors.blue,
          title: isId ? 'Bergabung sejak' : 'Member since',
          subtitle: _monthYear(user.createdAt, isId),
        ),
      ],
    );
  }
}

/// Numbers behind the Activity row and page.
class ActivityStats {
  final int count;
  final int streak;
  final double mySpendingThisMonth;
  const ActivityStats(this.count, this.streak, this.mySpendingThisMonth);
}

final activityStatsProvider = Provider<ActivityStats?>((ref) {
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
  final data = ref.watch(dashboardProvider).valueOrNull;
  if (uid == null || data == null) return null;
  final incomes = data.allIncomes.where((e) => e.userId == uid).toList();
  final expenses = data.allExpenses.where((e) => e.userId == uid).toList();
  final now = DateTime.now();
  final streak = recordingStreak([
    for (final e in incomes) e.createdAt,
    for (final e in expenses) e.createdAt,
  ], now);
  final mine = expenses
      .where(
        (e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.category != 'Tabungan' &&
            e.category != 'Savings',
      )
      .fold<double>(0, (s, e) => s + e.amount);
  return ActivityStats(incomes.length + expenses.length, streak, mine);
});

String activitySummary(ActivityStats? s, bool isId) {
  if (s == null) return '';
  final count = isId
      ? '${s.count} transaksi'
      : '${s.count} ${s.count == 1 ? 'transaction' : 'transactions'}';
  if (s.streak == 0) return count;
  final streak = isId
      ? '${s.streak} hari berturut-turut'
      : '${s.streak} ${s.streak == 1 ? 'day' : 'days'} in a row';
  return '$count · $streak';
}

/// The user's own recording: how many, how many days in a row, and (in a
/// family) their own spending this month.
class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final stats = ref.watch(activityStatsProvider);
    final familyMode = ref.watch(familyIdProvider).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(isId ? 'Aktivitas' : 'Activity')),
      body: stats == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MenuGroup(
                  footer: isId
                      ? 'Catat tiap hari biar rentetannya nggak putus.'
                      : 'Record something every day to keep the streak going.',
                  children: [
                    MenuRow(
                      icon: Icons.receipt_long_rounded,
                      color: MenuColors.blue,
                      title: isId
                          ? 'Transaksi dicatat'
                          : 'Transactions recorded',
                      value: '${stats.count}',
                    ),
                    MenuRow(
                      icon: Icons.local_fire_department_rounded,
                      color: MenuColors.orange,
                      title: isId ? 'Hari berturut-turut' : 'Days in a row',
                      value: '${stats.streak}',
                    ),
                    if (familyMode)
                      MenuRow(
                        icon: Icons.person_rounded,
                        color: MenuColors.red,
                        title: isId
                            ? 'Pengeluaranmu bulan ini'
                            : 'Your spending this month',
                        value: CurrencyFormatter.format(
                          stats.mySpendingThisMonth,
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Settings, guide, reports, updates and sign out.
class ProfileMoreGroups extends ConsumerWidget {
  const ProfileMoreGroups({super.key});

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    final strings = AppStrings(ref.read(localeProvider));
    final isId = ref.read(localeProvider).languageCode == 'id';
    final messenger = ScaffoldMessenger.of(context);
    try {
      final update = await AppUpdateService().checkForUpdate();
      if (!context.mounted) return;
      if (update == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isId ? 'Sudah versi terbaru.' : "You're on the latest version.",
            ),
          ),
        );
      } else {
        await showAppUpdateDialog(context, strings, update);
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isId
                ? 'Tidak bisa cek update. Cek koneksi lalu coba lagi.'
                : "Couldn't check for updates. Check your connection.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final strings = AppStrings(ref.watch(localeProvider));
    final version = ref.watch(_appVersionProvider).valueOrNull ?? '';

    return Column(
      children: [
        MenuGroup(
          children: [
            MenuRow(
              icon: Icons.settings_rounded,
              color: MenuColors.grey,
              title: strings.settings,
              subtitle: isId
                  ? 'Bahasa, mata uang, keamanan, tampilan'
                  : 'Language, currency, security, appearance',
              onTap: () => context.push('/settings'),
            ),
            MenuRow(
              icon: Icons.picture_as_pdf_rounded,
              color: MenuColors.pink,
              title: isId ? 'Laporan & PDF' : 'Reports & PDF',
              subtitle: isId
                  ? 'Ringkasan bulanan dan cetak'
                  : 'Monthly summary and printing',
              onTap: () => context.push('/reports'),
            ),
            MenuRow(
              icon: Icons.menu_book_rounded,
              color: MenuColors.teal,
              title: isId ? 'Panduan' : 'User guide',
              subtitle: isId ? 'Cara pakai aplikasi' : 'How to use the app',
              onTap: () => launchUrl(
                Uri.parse(
                  'https://family-finance.tzm.web.id/${isId ? 'id' : 'en'}/guide',
                ),
                mode: LaunchMode.externalApplication,
              ),
            ),
            MenuRow(
              icon: Icons.system_update_rounded,
              color: MenuColors.blue,
              title: isId ? 'Cek update' : 'Check for updates',
              subtitle: version.isEmpty
                  ? null
                  : (isId ? 'Versi $version' : 'Version $version'),
              onTap: () => _checkUpdate(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 20),
        MenuGroup(
          children: [
            MenuRow(
              icon: Icons.logout_rounded,
              color: MenuColors.red,
              title: strings.logout,
              danger: true,
              onTap: () => signOutUser(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}
