import 'dart:async';
import 'package:cableapp/data/supabase_client.dart';
import 'package:cableapp/features/auth/forgot_password_page.dart';
import 'package:cableapp/features/auth/login_page.dart';
import 'package:cableapp/features/auth/signup_page.dart';
import 'package:cableapp/features/complaints/complaints_page.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import 'package:cableapp/features/billing/billing_page.dart';
import 'package:cableapp/features/customers/customer_form_page.dart';
import 'package:cableapp/features/customers/customers_page.dart';
import 'package:cableapp/features/dashboard/dashboard_page.dart';
import 'package:cableapp/features/expenses/expenses_page.dart';
import 'package:cableapp/features/payments/payments_page.dart';
import 'package:cableapp/features/pending_payments/pending_payments_page.dart';
import 'package:cableapp/features/profile/profile_page.dart';
import 'package:cableapp/features/reports/reports_page.dart';
import 'package:cableapp/features/settings/settings_page.dart';
import 'package:cableapp/layouts/dashboard_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;

  _AuthRefreshNotifier() {
    // Only notify on sign-out so the router kicks the user to /login.
    // Forward navigation after login is handled by LoginPage itself,
    // preventing a race condition where the router redirects before
    // the admin check in AuthController.signIn() can complete.
    _sub = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier();
  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loggedIn = isSupabaseReady && supabase.auth.currentSession != null;
      final authRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/signup';
      if (!loggedIn && !authRoute) return '/login';
      if (loggedIn && state.matchedLocation == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersPage(),
          ),
          GoRoute(
            path: '/customers/new',
            builder: (context, state) => const CustomerFormPage(),
          ),
          GoRoute(
            path: '/customers/:id',
            builder: (context, state) =>
                CustomerFormPage(id: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/billing',
            builder: (context, state) => const BillingPage(),
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentsPage(),
          ),
          GoRoute(
            path: '/pending-payments',
            builder: (context, state) => const PendingPaymentsPage(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesPage(),
          ),
          GoRoute(
            path: '/complaints',
            builder: (context, state) => const ComplaintsPage(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
});
