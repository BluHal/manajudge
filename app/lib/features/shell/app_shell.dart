import 'package:flutter/material.dart';

import '../companion/companion_home.dart';
import '../judge/judge_screen.dart';
import '../search/search_screen.dart';

/// La home che lega le tre superfici: Companion (offline, gratis), Judge e Card Search (AI).
/// Un [IndexedStack] mantiene lo stato di ogni tab quando si naviga.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [CompanionHome(), JudgeScreen(), SearchScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.casino_outlined), selectedIcon: Icon(Icons.casino), label: 'Companion'),
          NavigationDestination(icon: Icon(Icons.balance_outlined), selectedIcon: Icon(Icons.balance), label: 'Judge'),
          NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Search'),
        ],
      ),
    );
  }
}
