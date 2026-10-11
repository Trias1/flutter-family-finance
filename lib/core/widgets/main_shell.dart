import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/app_update_service.dart';
import 'package:family_finance_manager/core/services/currency_provider.dart';
import 'package:family_finance_manager/core/services/recurring_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/budget/presentation/pages/budget_page.dart';
import 'package:family_finance_manager/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:family_finance_manager/features/transactions/presentation/pages/transactions_page.dart';
import 'package:family_finance_manager/features/settings/presentation/pages/profile_page.dart';
import 'package:family_finance_manager/features/expense/presentation/pages/expense_page.dart';
import 'package:family_finance_manager/features/income/presentation/pages/income_page.dart';
import 'package:family_finance_manager/core/services/bill_reminder_service.dart';
import 'package:family_finance_manager/core/services/notification_service.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';
import 'package:family_finance_manager/features/bills/presentation/providers/bill_provider.dart';
import 'package:family_finance_manager/core/widgets/announcement_banner.dart';
import 'package:family_finance_manager/core/services/receipt_parser.dart';
import 'package:family_finance_manager/core/services/receipt_scanner.dart';
import 'package:family_finance_manager/core/services/sheet_recap_service.dart';
import 'package:family_finance_manager/core/services/share_intake.dart';
import 'package:family_finance_manager/core/widgets/shell_app_bar.dart';
import 'package:family_finance_manager/core/widgets/shell_bell.dart';
import 'package:family_finance_manager/core/widgets/account_actions.dart';
import 'package:family_finance_manager/core/services/session_service.dart';
import 'package:family_finance_manager/core/services/balance_parser.dart';
import 'package:family_finance_manager/features/savings/presentation/widgets/balance_sync.dart';
import 'package:family_finance_manager/core/services/bank_inbox.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:family_finance_manager/features/bank_notifications/presentation/widgets/bank_inbox_banner.dart';
import 'package:family_finance_manager/core/biometric/app_lock.dart';
import 'package:family_finance_manager/features/transactions/presentation/pages/statement_import_page.dart';
import 'package:family_finance_manager/core/services/own_accounts.dart';

const _tabRoutes = ['/dashboard', '/transactions', '/budget', '/profile'];
const _tabPages = <Widget>[
  DashboardPage(),
  TransactionsPage(),
  BudgetPage(),
  ProfilePage(showAppBar: false),
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
  Timer? _recurringTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<void>? _shareSub;
  StreamSubscription<void>? _bankOpenSub;
  StreamSubscription<void>? _sessionSub;
  // Bank notifications kept while the app was away, and the access switch
  // the user may have just flipped in Android settings.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      ref.read(bankInboxProvider.notifier).refresh();
      ref.invalidate(bankAccessProvider);
    },
  );
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
    _lifecycle;
    // Waiting bank transactions that are already recorded need no check:
    // look when the dashboard data loads and when new ones arrive.
    ref.listenManual(
      dashboardProvider,
      (_, _) => _pruneRecordedBankRows(),
      fireImmediately: true,
    );
    ref.listenManual(bankInboxProvider, (prev, next) {
      if (next.length > (prev?.length ?? 0)) _pruneRecordedBankRows();
    });
    _lastLocation = widget.location;
  }

  @override
  void dispose() {
    _recurringTimer?.cancel();
    _heartbeatTimer?.cancel();
    _shareSub?.cancel();
    _bankOpenSub?.cancel();
    _sessionSub?.cancel();
    _lifecycle.dispose();
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
    // Load the family/personal currency as soon as the app opens, not only
    // when Settings is visited.
    ref.watch(currencyProvider);
    // Keep bill reminders in step with the bill list.
    ref.listen<AsyncValue<List<BillModel>>>(
      billStreamProvider(ref.watch(financeScopeIdProvider)),
      (_, next) => next.whenData(
        (bills) => BillReminderService.sync(
          bills,
          isId: ref.read(localeProvider).languageCode == 'id',
        ),
      ),
    );

    if (user != null && !_checkedUpdate) {
      _checkedUpdate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncDeviceAndCheckUpdate(user.id);
        _startRecurring(user.id);
        _startHeartbeat(user.id);
        _listenForShares();
        _listenForBankOpen();
        _watchSession(user.id);
      });
    }

    final location = widget.location;
    final isTab = _isTabRoute(location);
    final targetIndex = _tabIndex(location);

    if (location != _lastLocation) {
      // Coming back from a sub-page (e.g. /family) rebuilds the PageView;
      // start it on the current tab instead of the controller's first page.
      if (isTab && !_isTabRoute(_lastLocation)) {
        _pageController.dispose();
        _currentPage = targetIndex;
        _pageController = PageController(initialPage: targetIndex);
      }
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

    // Back on any tab other than Dashboard returns to Dashboard first,
    // like most phone apps; only Back on Dashboard leaves the app.
    // PopScope tells Android (predictive back) that Flutter handles Back;
    // BackButtonListener does the work, since tabs sit outside GoRouter's
    // navigator and a PopScope callback alone is never reached.
    // Only Dashboard may let Android close the app. With predictive back
    // (Android 14+), a PopScope that allows popping makes Android finish
    // the app itself without asking Flutter, which is how sub-pages such as
    // Bills closed the app on Back.
    return PopScope(
      canPop: isTab && _currentPage == 0,
      child: BackButtonListener(
        onBackButtonPressed: () async {
          // Pages pushed on top of the tabs (e.g. Import transactions) live
          // outside GoRouter's navigators, so GoRouter would close the app;
          // close the top page first.
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            await navigator.maybePop();
            return true;
          }
          if (!isTab) {
            // Sub-pages (Bills, Debts, Goals...) go back to where they were
            // opened from, or to Dashboard when opened directly.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(_tabRoutes[0]);
            }
            return true;
          }
          if (_currentPage == 0) return false;
          context.go(_tabRoutes[0]);
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            leading: !isTab
                // Sub-pages always get a way back, even when opened directly.
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(_tabRoutes[0]),
                  )
                : null,
            centerTitle: false,
            titleSpacing: isTab ? 20 : 0,
            toolbarHeight: isTab && _currentPage == 0 ? 64 : kToolbarHeight,
            title: ShellTitle(
              title: isTab
                  ? _tabTitle(strings, _currentPage)
                  : strings.titleForRoute(location),
              greet: isTab && _currentPage == 0,
            ),
            elevation: 0,
            scrolledUnderElevation: 1,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            actions: isTab
                ? const [ShellBell(), ShellMenu(), SizedBox(width: 4)]
                : null,
          ),
          drawer: null,
          body: SafeArea(
            child: Column(
              children: [
                const AnnouncementBanner(),
                // Waiting bank transactions are announced on Home only.
                if (isTab && _currentPage == 0) const BankInboxBanner(),
                Expanded(
                  child: isTab
                      ? PageView(
                          controller: _pageController,
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
              ],
            ),
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
        ),
      ),
    );
  }

  /// The sheet closes first and hands back what to do; opening a page in the
  /// same frame as closing the sheet left GoRouter with a stack that Back
  /// could not pop (it closed the app).
  Future<void> _showAddSheet(BuildContext context, AppStrings strings) async {
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddBottomSheet(
        strings: strings,
        shellContext: context,
        // The shell's ref outlives the sheet; the forms save through it.
        onIncome: () => IncomePage.openNew(context, ref),
        onExpense: () => ExpensePage.openNew(context, ref),
        onScan: _scanReceipt,
      ),
    );
    if (!mounted) return;
    action?.call();
  }

  /// Signs this device out when the user ends its session from another
  /// device (Profile > Devices).
  Future<void> _watchSession(String uid) async {
    await _sessionSub?.cancel();
    _sessionSub = await SessionService.watch(uid, () async {
      if (mounted) await signOutUser(context, ref);
    });
  }

  void _pruneRecordedBankRows() {
    final data = ref.read(dashboardProvider).valueOrNull;
    if (data == null || ref.read(bankInboxProvider).isEmpty) return;
    ref
        .read(bankInboxProvider.notifier)
        .pruneRecorded(
          incomes: [
            for (final e in data.allIncomes)
              (date: e.date, amount: e.amount, note: e.note),
          ],
          expenses: [
            for (final e in data.allExpenses)
              (date: e.date, amount: e.amount, note: e.note),
          ],
        );
  }

  /// The "transactions to check" notification: open the review screen when
  /// the app was started from it, and whenever it is tapped later.
  void _listenForBankOpen() {
    _bankOpenSub?.cancel();
    _bankOpenSub = BankNotifications.onOpenInbox.listen(
      (_) => _openBankInbox(),
    );
    BankNotifications.takeOpenRequest().then((open) {
      if (open) _openBankInbox();
    });
  }

  Future<void> _openBankInbox() async {
    await _whenUnlocked();
    if (!mounted) return;
    await ref.read(bankInboxProvider.notifier).refresh();
    if (!mounted) return;
    await reviewBankInbox(context, ref);
  }

  /// Waits for the fingerprint when the app is locked, so what opens next is
  /// shown on screen rather than under the lock.
  Future<void> _whenUnlocked() async {
    if (!ref.read(appLockProvider)) return;
    final unlocked = Completer<void>();
    final sub = ref.listenManual<bool>(appLockProvider, (_, locked) {
      if (!locked && !unlocked.isCompleted) unlocked.complete();
    });
    await unlocked.future;
    sub.close();
  }

  /// Images shared into the app: read now, and whenever another arrives.
  void _listenForShares() {
    _shareSub?.cancel();
    _shareSub = ShareIntake.onShared.listen((_) => _takeShared());
    _takeShared();
  }

  Future<void> _takeShared() async {
    final path = await ShareIntake.take();
    if (path == null || !mounted) return;
    // A share can open the app while it is locked: wait for the fingerprint
    // so the result shows on screen, not under the lock.
    await _whenUnlocked();
    if (!mounted) return;
    try {
      await _scanReceipt(false, sharedPath: path);
    } finally {
      // The copy was only for reading; do not keep the screenshot around.
      unawaited(File(path).delete().then((_) {}, onError: (_) {}));
    }
  }

  /// Photo or screenshot -> on-device text reading -> a filled expense form
  /// the user checks before saving. [sharedPath] is an image shared into the
  /// app instead of one picked here.
  Future<void> _scanReceipt(bool fromCamera, {String? sharedPath}) async {
    final isId = ref.read(localeProvider).languageCode == 'id';
    var showingProgress = false;
    ScanResult? scan;
    try {
      void showReading() {
        if (!mounted) return;
        showingProgress = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(isId ? 'Membaca struk…' : 'Reading the receipt…'),
                ),
              ],
            ),
          ),
        );
      }

      scan = sharedPath != null
          ? await ReceiptScanner.readFile(sharedPath, onReading: showReading)
          : await ReceiptScanner.pickAndRead(
              fromCamera: fromCamera,
              onReading: showReading,
            );
    } catch (_) {
      scan = const ScanResult(draft: ReceiptDraft(), items: []);
    } finally {
      if (showingProgress && mounted) Navigator.of(context).pop();
    }
    if (scan == null || !mounted) return;
    // A transaction list (mutasi): review and save every row at once.
    if (scan.isStatement) {
      final ownNames = await ref
          .read(ownAccountNamesProvider.future)
          .catchError((_) => const <String>[]);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              StatementImportPage(items: scan!.items, ownNames: ownNames),
        ),
      );
      return;
    }
    // A bank's account screen ("Saldo Rp3.000.000"): offer to set the goal
    // kept at that bank. "Not a savings balance" falls through to the
    // transaction flows below.
    final reading = BalanceParser.parse(scan.text);
    if (reading != null) {
      final handled = await offerBalanceUpdate(context, ref, reading);
      if (handled || !mounted) return;
    }
    final draft = scan.draft;
    if (draft.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isId
                ? 'Struk belum terbaca jelas. Isi nominalnya manual, ya.'
                : "Couldn't read the receipt clearly. Please fill in the amount.",
          ),
        ),
      );
    }
    // Salary or a transfer received is income; everything else is spending.
    if (draft.isIncoming) {
      await IncomePage.openFromReceipt(context, ref, draft);
    } else {
      await ExpensePage.openFromReceipt(context, ref, draft);
    }
  }

  /// "Active now" for the admin panel, like the web: every 60 seconds while
  /// the app is on screen; nothing is sent while it is in the background.
  void _startHeartbeat(String uid) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        AppUpdateService().heartbeat(uid);
      }
    });
  }

  /// Creates due recurring income/expenses now and then hourly, for the
  /// signed-in user's own entries in the current scope, then refreshes the
  /// Google Sheets recap when one is connected.
  void _startRecurring(String uid) {
    Future<void> run() async {
      try {
        await RecurringService().checkAndGenerate(
          scopeId: ref.read(financeScopeIdProvider),
          uid: uid,
        );
      } catch (_) {}
      // After recurring entries exist, so the recap includes them. Writes
      // at most once a day, and only if the user connected a spreadsheet.
      if (mounted) await ref.read(sheetRecapServiceProvider).autoSync();
    }

    run();
    _recurringTimer?.cancel();
    _recurringTimer = Timer.periodic(const Duration(hours: 1), (_) => run());
  }

  Future<void> _syncDeviceAndCheckUpdate(String uid) async {
    final service = AppUpdateService();
    try {
      await NotificationService().requestPermission();
      await service.registerDevice(uid);
      final update = await service.checkForUpdate();
      if (update != null && mounted) {
        unawaited(
          showAppUpdateDialog(
            context,
            AppStrings(ref.read(localeProvider)),
            update,
          ),
        );
      }
    } catch (_) {}
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
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
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
        // Keeps icon + label inside the 56px bar.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
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
              color: selected
                  ? AppTheme.primaryColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 2),
            // Long labels ("Dashboard", "Transaksi") shrink slightly
            // instead of being cut off.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? AppTheme.primaryColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBottomSheet extends ConsumerWidget {
  final AppStrings strings;

  /// The sheet closes before a form opens, so forms use the shell's context.
  final BuildContext shellContext;
  final VoidCallback onIncome;
  final VoidCallback onExpense;
  final void Function(bool fromCamera) onScan;

  const _AddBottomSheet({
    required this.strings,
    required this.shellContext,
    required this.onIncome,
    required this.onExpense,
    required this.onScan,
  });

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
              Navigator.pop(context, () => onIncome());
            },
          ),
          const SizedBox(height: 12),
          _AddOption(
            icon: Icons.trending_down_rounded,
            color: AppTheme.expenseColor,
            label: strings.expense,
            onTap: () {
              Navigator.pop(context, () => onExpense());
            },
          ),
          const SizedBox(height: 12),
          // Scan a receipt or a payment screenshot into a filled expense form.
          Row(
            children: [
              Expanded(
                child: _SmallAddOption(
                  icon: Icons.photo_camera_outlined,
                  color: AppTheme.expenseColor,
                  label: isId ? 'Foto struk' : 'Photo a receipt',
                  onTap: () {
                    Navigator.pop(context, () => onScan(true));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallAddOption(
                  icon: Icons.document_scanner_outlined,
                  color: AppTheme.expenseColor,
                  label: isId
                      ? 'Scan bukti transfer/bayar'
                      : 'Scan a transfer/payment',
                  onTap: () {
                    Navigator.pop(context, () => onScan(false));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Less frequent actions open their own pages, which hold the forms.
          Row(
            children: [
              Expanded(
                child: _SmallAddOption(
                  icon: Icons.savings_rounded,
                  color: AppTheme.savingsColor,
                  label: isId ? 'Setor tabungan' : 'Add to savings',
                  onTap: () {
                    Navigator.pop(context, () => shellContext.push('/savings'));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallAddOption(
                  icon: Icons.receipt_long_rounded,
                  color: AppTheme.warningColor,
                  label: isId ? 'Bayar tagihan' : 'Pay a bill',
                  onTap: () {
                    Navigator.pop(context, () => shellContext.push('/bills'));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallAddOption(
                  icon: Icons.swap_horiz_rounded,
                  color: AppTheme.primaryColor,
                  label: isId ? 'Hutang' : 'Debts',
                  onTap: () {
                    Navigator.pop(context, () => shellContext.push('/debts'));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallAddOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _SmallAddOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 12, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tab page in the swipeable PageView, kept alive so swiping back does
/// not rebuild it. Tabs slide plainly, like WhatsApp and Telegram: fading and
/// scaling a whole page every frame was the costliest effect on screen.
class _AnimatedPageView extends StatefulWidget {
  final Widget child;
  const _AnimatedPageView({
    required PageController controller,
    required int index,
    required this.child,
  });

  @override
  State<_AnimatedPageView> createState() => _AnimatedPageViewState();
}

class _AnimatedPageViewState extends State<_AnimatedPageView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
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
