import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tools/presentation/tools_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../projects/presentation/projects_screen.dart';
import '../../editor/presentation/timeline/editor_screen.dart';
import '../application/shell_tab_provider.dart';

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;

  const _NavDestination(this.icon, this.selectedIcon, this.label, this.screen);
}

/// Desktop breakpoint. Below this, RESONA uses bottom navigation; at or
/// above it, a persistent sidebar (spec section 9 / 41).
const double kDesktopBreakpoint = 900;

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static final _destinations = [
    const _NavDestination(Icons.home_outlined, Icons.home, 'Home', HomeScreen()),
    const _NavDestination(Icons.folder_outlined, Icons.folder, 'Projects', ProjectsScreen()),
    const _NavDestination(Icons.graphic_eq_outlined, Icons.graphic_eq, 'Editor', EditorScreen()),
    const _NavDestination(Icons.build_outlined, Icons.build, 'Tools', ToolsScreen()),
    const _NavDestination(Icons.settings_outlined, Icons.settings, 'Settings', SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(appShellTabIndexProvider);
    final isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    void select(int i) => ref.read(appShellTabIndexProvider.notifier).state = i;

    // IndexedStack (rather than swapping the child) keeps every screen's
    // state alive across tab switches — the Editor's timeline scroll
    // position and the audio player survive navigating away and back.
    final body = IndexedStack(
      index: index,
      children: [for (final d in _destinations) d.screen],
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: _Logo(),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.graphic_eq, color: Colors.white, size: 20),
    );
  }
}
