import 'package:cableapp/app.dart';
import 'package:cableapp/core/constants/nav_items.dart';
import 'package:cableapp/core/services/billing_cycle_service.dart';
import 'package:cableapp/core/widgets/app_logo.dart';
import 'package:cableapp/core/widgets/unit_tab_bar.dart';
import 'package:cableapp/data/supabase_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({
    required this.location,
    required this.child,
    super.key,
  });
  final String location;
  final Widget child;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  bool extended = true;

  @override
  void initState() {
    super.initState();
    BillingCycleService.ensureMonthlyBills();
  }

  int get selectedIndex {
    final index = navItems.indexWhere(
      (item) => item.path == '/'
          ? widget.location == '/'
          : widget.location.startsWith(item.path),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const UnitTabBar(),
            const SizedBox(height: 12),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 32),
            SizedBox(width: 10),
            Text(
              'CableCare Admin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        leading: compact
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : IconButton(
                tooltip: 'Collapse navigation',
                icon: Icon(extended ? Icons.menu_open : Icons.menu),
                onPressed: () => setState(() => extended = !extended),
              ),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (isSupabaseReady) {
                await supabase.auth.signOut();
              }
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      drawer: compact
          ? Drawer(child: _NavList(selectedIndex: selectedIndex))
          : null,
      body: compact
          ? content
          : Row(
              children: [
                NavigationRail(
                  extended: extended,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: extended
                        ? const AppLogo(
                            size: 36,
                            showText: true,
                            subtitle: 'Admin Console',
                          )
                        : const AppLogo(size: 36),
                  ),
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      context.go(navItems[index].path),
                  destinations: [
                    for (final item in navItems)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({required this.selectedIndex});
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
          ),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: AppLogo(
              size: 42,
              showText: true,
              subtitle: 'Network & Cable Operations',
            ),
          ),
        ),
        for (var i = 0; i < navItems.length; i++)
          ListTile(
            selected: i == selectedIndex,
            leading: Icon(navItems[i].icon),
            title: Text(navItems[i].label),
            onTap: () {
              Navigator.pop(context);
              context.go(navItems[i].path);
            },
          ),
      ],
    );
  }
}
