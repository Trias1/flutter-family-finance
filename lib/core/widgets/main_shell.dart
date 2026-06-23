import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/app_update_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/image_utils.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _checkedUpdate = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (user != null && !_checkedUpdate) {
      _checkedUpdate = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncDeviceAndCheckUpdate(user.id),
      );
    }

    if (isDesktop) return _DesktopShell(child: widget.child);
    return _MobileShell(child: widget.child);
  }

  Future<void> _syncDeviceAndCheckUpdate(String uid) async {
    final service = AppUpdateService();
    try {
      await service.registerDevice(uid);
      final update = await service.checkForUpdate();
      if (update != null && mounted) _showUpdateDialog(update);
    } catch (_) {
      // Update tracking must never block users from using the app.
    }
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    final strings = AppStrings(ref.read(localeProvider));
    showDialog(
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
}

class _DesktopShell extends ConsumerWidget {
  final Widget child;
  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final location = GoRouterState.of(context).matchedLocation;

    return Row(
      children: [
        _Sidebar(user: user, currentLocation: location),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _MobileShell extends ConsumerWidget {
  final Widget child;
  const _MobileShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final location = GoRouterState.of(context).matchedLocation;
    final strings = AppStrings(ref.watch(localeProvider));
    final title = strings.titleForRoute(location);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      drawer: _DrawerMenu(user: user, currentLocation: location),
      body: SafeArea(child: child),
      bottomNavigationBar: _BottomNav(currentLocation: location),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  final String currentLocation;
  const _BottomNav({required this.currentLocation});

  int _index(String loc) {
    if (loc.startsWith('/income')) return 1;
    if (loc.startsWith('/expense')) return 2;
    if (loc.startsWith('/savings')) return 3;
    if (loc.startsWith('/budget')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _index(currentLocation);
    final strings = AppStrings(ref.watch(localeProvider));
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) {
        final routes = [
          '/dashboard',
          '/income',
          '/expense',
          '/savings',
          '/budget',
        ];
        context.go(routes[i]);
      },
      indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.12),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(
            Icons.dashboard_rounded,
            color: AppTheme.primaryColor,
          ),
          label: strings.dashboard,
        ),
        NavigationDestination(
          icon: const Icon(Icons.trending_up_outlined),
          selectedIcon: const Icon(
            Icons.trending_up_rounded,
            color: AppTheme.incomeColor,
          ),
          label: strings.income,
        ),
        NavigationDestination(
          icon: const Icon(Icons.trending_down_outlined),
          selectedIcon: const Icon(
            Icons.trending_down_rounded,
            color: AppTheme.expenseColor,
          ),
          label: strings.expense,
        ),
        NavigationDestination(
          icon: const Icon(Icons.savings_outlined),
          selectedIcon: const Icon(
            Icons.savings_rounded,
            color: AppTheme.savingsColor,
          ),
          label: strings.savings,
        ),
        NavigationDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(
            Icons.account_balance_wallet_rounded,
            color: AppTheme.primaryColor,
          ),
          label: strings.budget,
        ),
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final dynamic user;
  final String currentLocation;

  const _Sidebar({required this.user, required this.currentLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(ref.watch(localeProvider));
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => context.push('/settings'),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: getAvatarProvider(user?.photoUrl),
                    child: user?.photoUrl == null
                        ? Text(
                            user?.name.isNotEmpty == true
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.name ?? strings.user,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            icon: Icons.dashboard_rounded,
            label: strings.dashboard,
            route: '/dashboard',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.trending_up_rounded,
            label: strings.income,
            route: '/income',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.trending_down_rounded,
            label: strings.expense,
            route: '/expense',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.receipt_long_rounded,
            label: strings.transactions,
            route: '/transactions',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.swap_horiz_rounded,
            label: strings.debts,
            route: '/debts',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.account_balance_wallet_rounded,
            label: strings.wallets,
            route: '/wallets',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.savings_rounded,
            label: strings.savings,
            route: '/savings',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.account_balance_wallet_rounded,
            label: strings.budget,
            route: '/budget',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.assessment_rounded,
            label: strings.reports,
            route: '/reports',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.repeat_rounded,
            label: strings.recurring,
            route: '/recurring',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.category_rounded,
            label: strings.categories,
            route: '/categories',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.family_restroom_rounded,
            label: strings.family,
            route: '/family',
            currentLocation: currentLocation,
          ),
          const Spacer(),
          const Divider(height: 1),
          _SidebarItem(
            icon: Icons.settings_rounded,
            label: strings.settings,
            route: '/settings',
            currentLocation: currentLocation,
          ),
          _SidebarItem(
            icon: Icons.privacy_tip_rounded,
            label: strings.privacySecurity,
            route: '/privacy-security',
            currentLocation: currentLocation,
          ),
          _LogoutButton(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentLocation;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = currentLocation.startsWith(route);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        dense: true,
        selected: active,
        selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(
          icon,
          size: 20,
          color: active
              ? AppTheme.primaryColor
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active
                ? AppTheme.primaryColor
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () => context.go(route),
      ),
    );
  }
}

class _DrawerMenu extends ConsumerWidget {
  final dynamic user;
  final String currentLocation;

  const _DrawerMenu({required this.user, required this.currentLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(ref.watch(localeProvider));
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: getAvatarProvider(user?.photoUrl),
                    child: user?.photoUrl == null
                        ? Text(
                            user?.name.isNotEmpty == true
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.name ?? strings.user,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.dashboard_rounded,
            label: strings.dashboard,
            route: '/dashboard',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.trending_up_rounded,
            label: strings.income,
            route: '/income',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.trending_down_rounded,
            label: strings.expense,
            route: '/expense',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.receipt_long_rounded,
            label: strings.transactions,
            route: '/transactions',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.swap_horiz_rounded,
            label: strings.debts,
            route: '/debts',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.account_balance_wallet_rounded,
            label: strings.wallets,
            route: '/wallets',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.savings_rounded,
            label: strings.savings,
            route: '/savings',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.account_balance_wallet_rounded,
            label: strings.budget,
            route: '/budget',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.assessment_rounded,
            label: strings.reports,
            route: '/reports',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.repeat_rounded,
            label: strings.recurring,
            route: '/recurring',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.category_rounded,
            label: strings.categories,
            route: '/categories',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.family_restroom_rounded,
            label: strings.family,
            route: '/family',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.settings_rounded,
            label: strings.settings,
            route: '/settings',
            currentLocation: currentLocation,
          ),
          _DrawerItem(
            icon: Icons.privacy_tip_rounded,
            label: strings.privacySecurity,
            route: '/privacy-security',
            currentLocation: currentLocation,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(
              Icons.logout_rounded,
              color: AppTheme.errorColor,
            ),
            title: Text(
              strings.logout,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
            onTap: () async {
              Navigator.pop(context);
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
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentLocation;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final active = currentLocation.startsWith(route);
    return ListTile(
      leading: Icon(icon, color: active ? AppTheme.primaryColor : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? AppTheme.primaryColor : null,
        ),
      ),
      selected: active,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(ref.watch(localeProvider));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          final uid = prefs.getString('biometric_last_uid');
          final bioEnabled =
              uid != null && (prefs.getBool('biometric_enabled_$uid') ?? false);
          if (bioEnabled)
            await prefs.setBool('biometric_skip_auto_login', true);
          await ref
              .read(authNotifierProvider.notifier)
              .signOut(keepGoogleSession: bioEnabled);
          if (context.mounted) context.go('/login');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 12),
              Text(
                strings.logout,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
