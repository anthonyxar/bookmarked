import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/genre_chip.dart';
import '../../widgets/goal_stepper.dart';

/// Edits the name, yearly reading goal and favourite genres. Also shown once,
/// with [firstTime] set, right after a first-time Google sign-in — that path
/// skips the register screen's pickers and would otherwise be stuck on the
/// defaults.
class EditProfileScreen extends ConsumerStatefulWidget {
  final bool firstTime;
  const EditProfileScreen({super.key, this.firstTime = false});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late int _goal;
  late final Set<String> _genres;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _goal = user?.readingGoal ?? 40;
    _genres = {...?user?.genres};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final name = _nameCtrl.text.trim();
    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: name.isEmpty ? null : name,
            readingGoal: _goal,
            genres: _genres.toList(),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your profile. Check your connection and try again.')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          widget.firstTime ? 'Set up your shelf' : 'Edit profile',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  const Text('YOUR NAME', style: labelCapsStyle),
                  const SizedBox(height: 6),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'e.g. Alex')),
                  const SizedBox(height: 18),
                  const Text('READING GOAL THIS YEAR', style: labelCapsStyle),
                  const SizedBox(height: 10),
                  GoalStepper(goal: _goal, onChanged: (v) => setState(() => _goal = v)),
                  const SizedBox(height: 18),
                  const Text('FAVOURITE GENRES', style: labelCapsStyle),
                  const SizedBox(height: 10),
                  GenrePicker(
                    selected: _genres,
                    onToggle: (g) => setState(() => _genres.contains(g) ? _genres.remove(g) : _genres.add(g)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
            if (widget.firstTime)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Skip for now', style: TextStyle(color: AppColors.inkSoft)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
