import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/app_update_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/theme/theme_provider.dart';
import 'package:family_finance_manager/core/utils/image_utils.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/budget/presentation/pages/budget_page.dart';
import 'package:family_finance_manager/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:family_finance_manager/features/transactions/presentation/pages/transactions_page.dart';
import 'package:family_finance_manager/features/settings/presentation/pages/profile_page.dart';

const _tabRoutes = ['/dashboard', '/transactions', '/budget', '/profile'];
const _tabPages = <Widget>[
  DashboardPage(),
  TransactionsPage(),
  BudgetPage(),
  ProfilePage(),
];

int _tabIndex(String loc) {
  if (loc == '/transactions' || loc.startsWith('/transactions/')) return 1;
  if (loc == '/budget' || loc.startsWith('/budget/')) return 2;
  if (loc == '/profile' || loc.startsWith('/profile/')) return 3;
  return 0;
}

bool _isTabRoute(String loc) {
  return _tabRoutes.contains(loc);
}

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const MainShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _checkedUpdate = false;
  late PageController _pageController;
  bool _isProgrammaticUpdate = false;
  bool _syncScheduled = false;
  int _currentPage = 0;
  String _lastLocation = '';

  @override
  void initState() {
    super.initState();
    _currentPage = _tabIndex(widget.location);
    _pageController = PageController(initialPage: _currentPage);
    _lastLocation = widget.location;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() {
      _currentPage = index;
    });
    if (!_isProgrammaticUpdate && widget.location != _tabRoutes[index]) {
      context.go(_tabRoutes[index]);
    }
  }

  String _tabTitle(AppStrings strings, int index) {
    switch (index) {
      case 0:
        return strings.dashboard;
      case 1:
        return strings.transactions;
      case 2:
        return strings.budget;
      case 3:
        return strings.profile;
      default:
        return strings.dashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    if (user != null && !_checkedUpdate) {
      _checkedUpdate = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncDeviceAndCheckUpdate(user.id),
      );
    }

    final location = widget.location;
    final isTab = _isTabRoute(location);
    final targetIndex = _tabIndex(location);

    if (location != _lastLocation) {
      _lastLocation = location;
      if (isTab &&
          _pageController.hasClients &&
          !_isProgrammaticUpdate &&
          !_syncScheduled &&
          _currentPage != targetIndex) {
        _syncScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _syncScheduled = false;
          _isProgrammaticUpdate = true;
          _pageController
              .animateToPage(
                targetIndex,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              )
              .whenComplete(() {
                if (mounted) _isProgrammaticUpdate = false;
              });
        });
      }
    }

    final strings = AppStrings(ref.watch(localeProvider));

    return Scaffold(
      appBar: AppBar(
        leading: !isTab && context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          isTab
              ? _tabTitle(strings, _currentPage)
              : strings.titleForRoute(location),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: [_ProfilePopup(user: user)],
      ),
      drawer: null,
      body: SafeArea(
        child: isTab
            ? PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: List.generate(
                  _tabPages.length,
                  (i) => _AnimatedPageView(
                    controller: _pageController,
                    index: i,
                    child: _tabPages[i],
                  ),
                ),
              )
            : widget.child,
      ),
      bottomNavigationBar: isTab
          ? _FloatingBottomNav(
              currentIndex: _currentPage,
              onTabChanged: (i) async {
                if (i == _currentPage) return;
                _isProgrammaticUpdate = true;
                await _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                );
                if (mounted) {
                  context.go(_tabRoutes[i]);
                  _isProgrammaticUpdate = false;
                }
              },
              onFabTap: () => _showAddSheet(context, strings),
            )
          : null,
    );
  }

  void _showAddSheet(BuildContext context, AppStrings strings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddBottomSheet(strings: strings),
    );
  }

  Future<void> _syncDeviceAndCheckUpdate(String uid) async {
    final service = AppUpdateService();
    try {
      await service.registerDevice(uid);
      final update = await service.checkForUpdate();
      if (update != null && mounted) _showUpdateDialog(update);
    } catch (_) {}
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

class _FloatingBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onFabTap;

  const _FloatingBottomNav({
    required this.currentIndex,
    required this.onTabChanged,
    required this.onFabTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(ref.watch(localeProvider));
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, isDesktop ? 16 : 12),
      child: SizedBox(
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.dashboard_outlined,
                      selectedIcon: Icons.dashboard_rounded,
                      label: strings.dashboard,
                      selected: currentIndex == 0,
                      onTap: () => onTabChanged(0),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.receipt_long_outlined,
                      selectedIcon: Icons.receipt_long_rounded,
                      label: strings.transactions,
                      selected: currentIndex == 1,
                      onTap: () => onTabChanged(1),
                    ),
                  ),
                  const SizedBox(width: 56), // Space for FAB
                  Expanded(
                    child: _NavItem(
                      icon: Icons.pie_chart_outline_outlined,
                      selectedIcon: Icons.pie_chart_rounded,
                      label: strings.budget,
                      selected: currentIndex == 2,
                      onTap: () => onTabChanged(2),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      label: strings.profile,
                      selected: currentIndex == 3,
                      onTap: () => onTabChanged(3),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: -8,
              child: Center(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    onPressed: onFabTap,
                    backgroundColor: AppTheme.primaryColor,
                    shape: const CircleBorder(),
                    elevation: 6,
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              color: selected ? AppTheme.primaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppTheme.primaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePopup extends ConsumerWidget {
  final dynamic user;

  const _ProfilePopup({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final strings = AppStrings(ref.watch(localeProvider));
    final isId = locale.languageCode == 'id';

    void openRoute(String route) {
      Future<void>.delayed(Duration.zero, () {
        if (context.mounted) context.push(route);
      });
    }

    void toggleTheme() {
      Future<void>.delayed(Duration.zero, () async {
        final themeNotifier = ref.read(themeModeProvider.notifier);
        await themeNotifier.toggle();
      });
    }

    void logout() {
      Future<void>.delayed(Duration.zero, () async {
        final prefs = await SharedPreferences.getInstance();
        final uid = prefs.getString('biometric_last_uid');
        final bioEnabled =
            uid != null && (prefs.getBool('biometric_enabled_$uid') ?? false);
        if (bioEnabled) {
          await prefs.setBool('biometric_skip_auto_login', true);
        }
        await ref
            .read(authNotifierProvider.notifier)
            .signOut(keepGoogleSession: bioEnabled);
        if (context.mounted) context.go('/login');
      });
    }

    return PopupMenuButton<void>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        PopupMenuItem(
          onTap: () => openRoute('/settings'),
          child: ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: Text(strings.settings),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          onTap: toggleTheme,
          child: ListTile(
            leading: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            title: Text(
              themeMode == ThemeMode.dark
                  ? (isId ? 'Mode Terang' : 'Light Mode')
                  : (isId ? 'Mode Gelap' : 'Dark Mode'),
            ),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          onTap: logout,
          child: ListTile(
            leading: const Icon(
              Icons.logout_rounded,
              color: AppTheme.errorColor,
            ),
            title: Text(
              strings.logout,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            backgroundImage: getAvatarProvider(user?.photoUrl),
            child: user?.photoUrl == null
                ? Text(
                    user?.name.isNotEmpty == true
                        ? user.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _AddBottomSheet extends ConsumerWidget {
  final AppStrings strings;

  const _AddBottomSheet({required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final locale = ref.watch(localeProvider);
    final isId = locale.languageCode == 'id';

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, isDesktop ? 24 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          _AddOption(
            icon: Icons.trending_up_rounded,
            color: AppTheme.incomeColor,
            label: strings.income,
            onTap: () {
              Navigator.pop(context);
              context.push('/income');
            },
          ),
          const SizedBox(height: 12),
          _AddOption(
            icon: Icons.trending_down_rounded,
            color: AppTheme.expenseColor,
            label: strings.expense,
            onTap: () {
              Navigator.pop(context);
              context.push('/expense');
            },
          ),
          const SizedBox(height: 12),
          _AddOption(
            icon: Icons.camera_alt_rounded,
            color: AppTheme.savingsColor,
            label: isId ? 'Pindai Struk' : 'Scan Receipt',
            onTap: () {
              Navigator.pop(context);
              context.push('/scan-receipt');
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedPageView extends AnimatedWidget {
  final int index;
  final Widget child;

  const _AnimatedPageView({
    required PageController controller,
    required this.index,
    required this.child,
  }) : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    final controller = listenable as PageController;
    if (!controller.hasClients) return child;

    final page = controller.page ?? index.toDouble();
    final distance = (page - index).abs().clamp(0.0, 1.0);

    final scale = 1.0 - (distance * 0.15);
    final opacity = 1.0 - (distance * 0.6);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _AddOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
