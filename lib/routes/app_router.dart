import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_manager/core/widgets/main_shell.dart';
import 'package:family_finance_manager/features/ai_advisor/presentation/pages/ai_advisor_page.dart';
import 'package:family_finance_manager/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:family_finance_manager/features/auth/presentation/pages/login_page.dart';
import 'package:family_finance_manager/features/auth/presentation/pages/register_page.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/budget/presentation/pages/budget_page.dart';
import 'package:family_finance_manager/features/dashboard/presentation/pages/dashboard_settings_page.dart';
import 'package:family_finance_manager/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:family_finance_manager/features/expense/presentation/pages/expense_page.dart';
import 'package:family_finance_manager/features/family/presentation/pages/family_page.dart';
import 'package:family_finance_manager/features/income/presentation/pages/income_page.dart';
import 'package:family_finance_manager/features/savings/presentation/pages/savings_page.dart';
import 'package:family_finance_manager/features/reports/presentation/pages/reports_page.dart';
import 'package:family_finance_manager/features/settings/presentation/pages/backup_page.dart';
import 'package:family_finance_manager/features/settings/presentation/pages/settings_page.dart';
import 'package:family_finance_manager/features/settings/presentation/pages/privacy_security_page.dart';
import 'package:family_finance_manager/features/settings/presentation/pages/profile_page.dart';
import 'package:family_finance_manager/features/transactions/presentation/pages/transactions_page.dart';
import 'package:family_finance_manager/features/categories/presentation/pages/categories_page.dart';
import 'package:family_finance_manager/features/debts/presentation/pages/debts_page.dart';
import 'package:family_finance_manager/features/bills/presentation/pages/bills_page.dart';
import 'package:family_finance_manager/features/recurring/presentation/pages/recurring_page.dart';
import 'package:family_finance_manager/features/receipt_scanner/presentation/pages/receipt_scanner_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final firebaseUser = authState.valueOrNull;
      final isLoggedIn = firebaseUser != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/income',
            name: 'income',
            builder: (context, state) => const IncomePage(),
          ),
          GoRoute(
            path: '/expense',
            name: 'expense',
            builder: (context, state) => const ExpensePage(),
          ),
          GoRoute(
            path: '/savings',
            name: 'savings',
            builder: (context, state) => const SavingsPage(),
          ),
          GoRoute(
            path: '/budget',
            name: 'budget',
            builder: (context, state) => const BudgetPage(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/ai-advisor',
            name: 'aiAdvisor',
            builder: (context, state) => const AiAdvisorPage(),
          ),
          GoRoute(
            path: '/dashboard-settings',
            name: 'dashboardSettings',
            builder: (context, state) => const DashboardSettingsPage(),
          ),
          GoRoute(
            path: '/scan-receipt',
            name: 'scanReceipt',
            builder: (context, state) => const ReceiptScannerPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/privacy-security',
            name: 'privacySecurity',
            builder: (context, state) => const PrivacySecurityPage(),
          ),
          GoRoute(
            path: '/settings/profile',
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/transactions',
            name: 'transactions',
            builder: (context, state) => const TransactionsPage(),
          ),
          GoRoute(
            path: '/debts',
            name: 'debts',
            builder: (context, state) => const DebtsPage(),
          ),
          GoRoute(
            path: '/bills',
            name: 'bills',
            builder: (context, state) => const BillsPage(),
          ),
          GoRoute(
            path: '/recurring',
            name: 'recurring',
            builder: (context, state) => const RecurringPage(),
          ),
          GoRoute(
            path: '/categories',
            name: 'categories',
            builder: (context, state) => const CategoriesPage(),
          ),
          GoRoute(
            path: '/family',
            name: 'family',
            builder: (context, state) => const FamilyPage(),
          ),
          GoRoute(
            path: '/backup',
            name: 'backup',
            builder: (context, state) => const BackupPage(),
          ),
        ],
      ),
    ],
  );
});
