import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/app_update_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/widgets/account_actions.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';

// Extra sections on the Profile tab: account facts, the user's own activity,
// the phones signed in, and shortcuts.

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

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? color;
  final VoidCallback? onTap;
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? scheme.onSurfaceVariant, size: 22),
      title: Text(title, style: TextStyle(fontSize: 14, color: color)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12)),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                )),
    );
  }
}

/// How the user signs in, whether the email is verified, and since when.
class AccountInfoSection extends ConsumerWidget {
  const AccountInfoSection({super.key});

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
      if (password) (isId ? 'Email & password' : 'Email & password'),
    ].join(' + ');
    final verified = auth.emailVerified || google;

    return _Section(
      title: isId ? 'Akun' : 'Account',
      children: [
        _Row(
          icon: google ? Icons.g_mobiledata_rounded : Icons.key_rounded,
          title: isId ? 'Cara masuk' : 'Signs in with',
          subtitle: method.isEmpty ? '-' : method,
        ),
        _Row(
          icon: verified
              ? Icons.verified_rounded
              : Icons.mark_email_unread_outlined,
          color: verified ? AppTheme.incomeColor : AppTheme.warningColor,
          title: verified
              ? (isId ? 'Email terverifikasi' : 'Email verified')
              : (isId ? 'Email belum terverifikasi' : 'Email not verified'),
          subtitle: user.email,
        ),
        _Row(
          icon: Icons.event_available_rounded,
          title: isId ? 'Bergabung sejak' : 'Member since',
          subtitle: _monthYear(user.createdAt, isId),
        ),
      ],
    );
  }
}

/// What the user has recorded: how many, how many days in a row, and (in a
/// family) their own spending this month.
class ActivitySection extends ConsumerWidget {
  const ActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
    final familyMode = ref.watch(familyIdProvider).isNotEmpty;
    final data = ref.watch(dashboardProvider).valueOrNull;
    if (uid == null || data == null) return const SizedBox.shrink();

    final incomes = data.allIncomes.where((e) => e.userId == uid).toList();
    final expenses = data.allExpenses.where((e) => e.userId == uid).toList();
    final count = incomes.length + expenses.length;
    final now = DateTime.now();
    final streak = recordingStreak([
      for (final e in incomes) e.createdAt,
      for (final e in expenses) e.createdAt,
    ], now);
    final mySpending = expenses
        .where(
          (e) =>
              e.date.year == now.year &&
              e.date.month == now.month &&
              e.category != 'Tabungan' &&
              e.category != 'Savings',
        )
        .fold<double>(0, (s, e) => s + e.amount);

    return _Section(
      title: isId ? 'Aktivitas kamu' : 'Your activity',
      children: [
        _Row(
          icon: Icons.receipt_long_rounded,
          title: isId
              ? '$count transaksi dicatat'
              : '$count ${count == 1 ? 'transaction' : 'transactions'} recorded',
        ),
        _Row(
          icon: Icons.local_fire_department_rounded,
          color: streak > 0 ? AppTheme.warningColor : null,
          title: streak > 0
              ? (isId
                    ? 'Mencatat $streak hari berturut-turut'
                    : 'Recorded $streak ${streak == 1 ? 'day' : 'days'} in a row')
              : (isId
                    ? 'Belum ada catatan hari ini'
                    : 'Nothing recorded today'),
          subtitle: streak > 0
              ? (isId
                    ? 'Catat tiap hari biar nggak putus.'
                    : 'Record something every day to keep it going.')
              : (isId
                    ? 'Catat satu transaksi untuk mulai.'
                    : 'Record a transaction to start a streak.'),
        ),
        if (familyMode)
          _Row(
            icon: Icons.person_outline_rounded,
            title: isId
                ? 'Pengeluaranmu bulan ini'
                : 'Your spending this month',
            trailing: Text(
              CurrencyFormatter.format(mySpending),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.expenseColor,
              ),
            ),
          ),
      ],
    );
  }
}

final _myDevicesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
      if (uid == null) return Stream.value(const []);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices')
          .snapshots()
          .map((snap) {
            final list = [
              for (final d in snap.docs) {...d.data(), 'id': d.id},
            ];
            list.sort((a, b) {
              final ta = a['lastSeenAt'] as Timestamp?;
              final tb = b['lastSeenAt'] as Timestamp?;
              return (tb?.millisecondsSinceEpoch ?? 0).compareTo(
                ta?.millisecondsSinceEpoch ?? 0,
              );
            });
            return list;
          })
          .handleError((_) {});
    });

final _thisDeviceIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('device_registry_id');
});

/// The Android phones signed in to this account, newest first, so a phone
/// the user does not recognise stands out.
class DevicesSection extends ConsumerWidget {
  const DevicesSection({super.key});

  String _ago(DateTime t, bool isId) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 2) return isId ? 'aktif sekarang' : 'active now';
    if (d.inHours < 1) {
      return isId ? '${d.inMinutes} menit lalu' : '${d.inMinutes} min ago';
    }
    if (d.inDays < 1) {
      return isId ? '${d.inHours} jam lalu' : '${d.inHours} h ago';
    }
    if (isId) return '${d.inDays} hari lalu';
    return d.inDays == 1 ? '1 day ago' : '${d.inDays} days ago';
  }

  static const _os = {
    'Win32': 'Windows',
    'Win64': 'Windows',
    'MacIntel': 'Mac',
    'Linux x86_64': 'Linux',
  };

  Widget _deviceRow(
    BuildContext context,
    String uid,
    Map<String, dynamic> d,
    bool mine,
    bool isId,
  ) {
    final web = d['platform'] == 'web';
    final brand = (d['brand'] ?? '').toString().trim();
    final model = (d['model'] ?? '').toString().trim();
    final version = (d['androidVersion'] ?? '').toString().trim();
    final app = (d['appVersionName'] ?? '').toString().trim();
    final name = web
        ? [brand, _os[model] ?? model].where((s) => s.isNotEmpty).join(' · ')
        : '$brand $model'.trim();
    return _Row(
      icon: web ? Icons.laptop_rounded : Icons.phone_android_rounded,
      color: mine ? AppTheme.primaryColor : null,
      title: name,
      subtitle: [
        if (web) 'Browser' else if (version.isNotEmpty) 'Android $version',
        if (!web && app.isNotEmpty) 'App $app',
        if (!mine && d['lastSeenAt'] is Timestamp)
          _ago((d['lastSeenAt'] as Timestamp).toDate(), isId),
      ].join(' · '),
      trailing: mine
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.incomeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isId ? 'Sedang dipakai' : 'In use',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.incomeColor,
                ),
              ),
            )
          : IconButton(
              tooltip: isId ? 'Hapus dari daftar' : 'Remove from list',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () =>
                  _remove(context, uid, d['id'] as String, name, isId),
            ),
    );
  }

  /// Removes the entry only: Firebase cannot sign out one device, so a
  /// phone still signed in comes back the next time it opens the app.
  Future<void> _remove(
    BuildContext context,
    String uid,
    String deviceId,
    String name,
    bool isId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isId ? 'Hapus perangkat?' : 'Remove device?'),
        content: Text(
          isId
              ? '$name dihapus dari daftar. Kalau perangkat itu masih masuk ke akunmu, ia akan muncul lagi saat aplikasinya dibuka. Kalau kamu tidak mengenalinya, ganti password.'
              : '$name leaves the list. If it is still signed in to your account it shows up again when the app opens there. If you do not recognise it, change your password.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isId ? 'Batal' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isId ? 'Hapus' : 'Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .delete();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isId
                  ? 'Gagal menghapus. Cek koneksi lalu coba lagi.'
                  : "Couldn't remove it. Check your connection.",
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final devices = ref.watch(_myDevicesProvider).valueOrNull ?? const [];
    final thisId = ref.watch(_thisDeviceIdProvider).valueOrNull;
    final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
    if (devices.isEmpty || uid == null) return const SizedBox.shrink();

    return _Section(
      title: isId ? 'Perangkat yang masuk' : 'Signed-in devices',
      children: [
        for (final d in devices)
          _deviceRow(context, uid, d, d['id'] == thisId, isId),
      ],
    );
  }
}

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Quick ways to the places people look for on a profile page.
class ShortcutsSection extends ConsumerWidget {
  const ShortcutsSection({super.key});

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

    return _Section(
      title: isId ? 'Lainnya' : 'More',
      children: [
        _Row(
          icon: Icons.settings_outlined,
          title: strings.settings,
          onTap: () => context.push('/settings'),
        ),
        _Row(
          icon: Icons.menu_book_outlined,
          title: isId ? 'Panduan penggunaan' : 'User guide',
          onTap: () => launchUrl(
            Uri.parse(
              'https://family-finance.tzm.web.id/${isId ? 'id' : 'en'}/guide',
            ),
            mode: LaunchMode.externalApplication,
          ),
        ),
        _Row(
          icon: Icons.picture_as_pdf_outlined,
          title: isId ? 'Laporan & ekspor PDF' : 'Reports & PDF export',
          onTap: () => context.push('/reports'),
        ),
        _Row(
          icon: Icons.system_update_outlined,
          title: isId ? 'Cek update' : 'Check for updates',
          subtitle: version.isEmpty
              ? null
              : (isId ? 'Versi $version' : 'Version $version'),
          onTap: () => _checkUpdate(context, ref),
        ),
        _Row(
          icon: Icons.logout_rounded,
          color: AppTheme.errorColor,
          title: strings.logout,
          onTap: () => signOutUser(context, ref),
        ),
      ],
    );
  }
}
