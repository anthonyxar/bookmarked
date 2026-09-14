import 'package:flutter/material.dart';

import '../../theme.dart';
import 'bingo_screen.dart';
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
    BingoScreen(),
    ProfileScreen(),
  ];

  static const _tabs = [
    (icon: Icons.menu_book_outlined, label: 'Shelf'),
    (icon: Icons.bar_chart_rounded, label: 'Stats'),
    (icon: Icons.grid_on_rounded, label: 'Bingo'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: IndexedStack(index: _index, children: _screens),
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
    );
  }
}
