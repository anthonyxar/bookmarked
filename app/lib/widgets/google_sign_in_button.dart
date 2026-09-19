import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';

/// "Continue with Google" — shared by the register and login screens, since
/// Google sign-in creates the profile on first use and just signs in after.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(authProvider.notifier).signInWithGoogle();
    final error = ref.read(authProvider).error;
    if (!ok && error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authProvider).loading;
    return OutlinedButton.icon(
      onPressed: loading ? null : () => _onPressed(context, ref),
      icon: const Icon(Icons.g_mobiledata, size: 22),
      label: const Text('Continue with Google'),
    );
  }
}

/// A hairline rule with a centred label, separating Google sign-in from the
/// email form.
class OrDivider extends StatelessWidget {
  final String label;
  const OrDivider({super.key, this.label = 'OR'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
        ),
        const Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }
}
