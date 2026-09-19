import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../clubs/clubs_list_screen.dart';
import 'bingo_screen.dart';
import 'challenges_screen.dart';
import 'dashboard_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // The flag can already be set by the time the shell exists (the profile
    // snapshot landed after signInWithGoogle finished), so check once here as
    // well as listening for it in build().
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowProfileSetup());
  }

  /// After a first-time Google sign-in, ask for the goal and genres the
  /// register screen would have collected. Cleared before pushing so back,
  /// skip and save all leave it done.
  void _maybeShowProfileSetup() {
    if (!mounted || !ref.read(authProvider).needsProfileSetup) return;
    ref.read(authProvider.notifier).markProfileSetupDone();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen(firstTime: true)));
  }

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
    ref.listen<bool>(authProvider.select((s) => s.needsProfileSetup), (_, needs) {
      if (needs) _maybeShowProfileSetup();
    });

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
