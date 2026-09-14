import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../home/home_shell.dart';
import 'welcome_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.initializing) {
      return const Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }

    return auth.isAuthenticated ? const HomeShell() : const WelcomeScreen();
  }
}
