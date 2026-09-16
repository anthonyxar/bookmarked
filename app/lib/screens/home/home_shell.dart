import 'package:flutter/material.dart';

import '../../theme.dart';
import '../clubs/clubs_list_screen.dart';
import 'bingo_screen.dart';
import 'challenges_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    WishlistScreen(),
    DashboardScreen(),
    ClubsListScreen(),
    BingoScreen(),
    ChallengesScreen(),
    ProfileScreen(),
  ];

  static const _tabs = [
    (icon: Icons.menu_book_outlined, label: 'Shelf'),
    (icon: Icons.bar_chart_rounded, label: 'Stats'),
    (icon: Icons.groups_outlined, label: 'Clubs'),
    (icon: Icons.grid_on_rounded, label: 'Bingo'),
    (icon: Icons.emoji_events_outlined, label: 'Challenges'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  final _navigatorKeys = List.generate(_screens.length, (_) => GlobalKey<NavigatorState>());

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigatorKeys[_index].currentState?.maybePop();
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: IndexedStack(
          index: _index,
          children: List.generate(
            _screens.length,
            (i) => Navigator(
              key: _navigatorKeys[i],
              onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => _screens[i]),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.paperSoft,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 60,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final active = i == _index;
                  final color = active ? AppColors.green : AppColors.lineStrong;
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _index = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tab.icon, size: 20, color: color),
                          const SizedBox(height: 3),
                          Text(tab.label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
