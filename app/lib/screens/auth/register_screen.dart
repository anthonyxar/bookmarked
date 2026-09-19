import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/genre_chip.dart';
import '../../widgets/google_sign_in_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToLogin;
  const RegisterScreen({super.key, required this.onSwitchToLogin});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  int _goal = 40;
  final Set<String> _genres = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim().isEmpty ? 'Reader' : _nameCtrl.text.trim();
    final ok = await ref.read(authProvider.notifier).register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: name,
          readingGoal: _goal,
          genres: _genres.isEmpty ? ['Romance', 'Fantasy'] : _genres.toList(),
        );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 32, 26, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  const AppIcon(size: 48),
                  const SizedBox(height: 10),
                  Text('Bookmarked', style: AppTheme.display.copyWith(fontSize: 30)),
                  const SizedBox(height: 4),
                  const Text('YOUR READING, REMEMBERED',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.inkSoft)),
                ],
              ),
              const SizedBox(height: 28),
              const GoogleSignInButton(),
              const SizedBox(height: 14),
              const OrDivider(label: 'OR SIGN UP WITH EMAIL'),
              const SizedBox(height: 22),
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
                    Text("Let's set up your shelf", style: GoogleFonts.spectral(fontSize: 18, color: AppColors.ink)),
                    const SizedBox(height: 18),
                    const Text('YOUR NAME', style: labelCapsStyle),
                    const SizedBox(height: 6),
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'e.g. Alex')),
                    const SizedBox(height: 16),
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
                      decoration: const InputDecoration(hintText: 'At least 8 characters'),
                    ),
                    const SizedBox(height: 18),
                    const Text('READING GOAL THIS YEAR', style: labelCapsStyle),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StepperButton(icon: Icons.remove, onTap: () => setState(() => _goal = (_goal - 5).clamp(5, 999))),
                        Expanded(
                          child: Center(
                            child: RichText(
                              text: TextSpan(children: [
                                TextSpan(text: '$_goal ', style: GoogleFonts.spectral(fontSize: 26, color: AppColors.ink)),
                                const TextSpan(text: 'books', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                              ]),
                            ),
                          ),
                        ),
                        _StepperButton(icon: Icons.add, onTap: () => setState(() => _goal += 5)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('PICK A FEW GENRES YOU LOVE', style: labelCapsStyle),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: genreOptions
                          .map((g) => GenreChip(
                                label: g,
                                active: _genres.contains(g),
                                onTap: () => setState(() => _genres.contains(g) ? _genres.remove(g) : _genres.add(g)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: auth.loading ? null : _submit,
                child: auth.loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Start My Journal'),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: widget.onSwitchToLogin,
                  child: const Text('Already have a shelf? Log in', style: TextStyle(color: AppColors.inkSoft)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.lineStrong)),
        child: Icon(icon, size: 18, color: AppColors.green),
      ),
    );
  }
}
