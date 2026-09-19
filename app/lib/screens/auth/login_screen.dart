import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToRegister;
  const LoginScreen({super.key, required this.onSwitchToRegister});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(authProvider.notifier).login(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    if (!ok && mounted) {
      final error = ref.read(authProvider).error ?? 'Something went wrong';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 60, 26, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  const AppIcon(size: 48),
                  const SizedBox(height: 10),
                  Text('Bookmarked', style: AppTheme.display.copyWith(fontSize: 30)),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.paperSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back', style: GoogleFonts.spectral(fontSize: 18, color: AppColors.ink)),
                    const SizedBox(height: 18),
                    const Text('EMAIL', style: labelCapsStyle),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: 'you@example.com'),
                    ),
                    const SizedBox(height: 16),
                    const Text('PASSWORD', style: labelCapsStyle),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(hintText: 'Your password'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: auth.loading ? null : _submit,
                child: auth.loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Log In'),
              ),
              const SizedBox(height: 14),
              const OrDivider(),
              const SizedBox(height: 14),
              const GoogleSignInButton(),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: widget.onSwitchToRegister,
                  child: const Text('New here? Create your shelf', style: TextStyle(color: AppColors.inkSoft)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
