import 'package:flutter/material.dart';

class NavItem {
  const NavItem(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

const navItems = [
  NavItem('Dashboard', '/', Icons.dashboard_outlined),
  NavItem('Customers', '/customers', Icons.people_outline),
  NavItem('Payments', '/payments', Icons.payments_outlined),
  NavItem(
    'Pending Payments',
    '/pending-payments',
    Icons.pending_actions_outlined,
  ),
  NavItem('Expenses', '/expenses', Icons.account_balance_wallet_outlined),
  NavItem('Complaints', '/complaints', Icons.report_problem_outlined),
  NavItem('Reports', '/reports', Icons.analytics_outlined),
  NavItem('Settings', '/settings', Icons.settings_outlined),
  NavItem('Profile', '/profile', Icons.person_outline),
];
