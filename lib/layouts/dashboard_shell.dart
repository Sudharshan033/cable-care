import 'package:cableapp/app.dart';
import 'package:cableapp/core/constants/nav_items.dart';
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
      child: Padding(padding: const EdgeInsets.all(16), child: widget.child),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('CableCare Admin'),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        const ListTile(title: Text('CableCare Admin')),
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
