import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import 'goal_stepper.dart';

/// Opens the "reading goal for [year]" editor. Goals are per year, so this is
/// how a goal is first set (for a new year, starting from last year's number)
/// and how it's changed later — used from the Stats and Profile pages.
Future<void> showReadingGoalSheet(BuildContext context, WidgetRef ref, {required int year}) async {
  final user = ref.read(authProvider).user;
  if (user == null) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.paperSoft,
    builder: (_) => _ReadingGoalSheet(year: year, initial: user.goalFor(year) ?? user.suggestedGoalFor(year), isNew: user.goalFor(year) == null),
  );
}

class _ReadingGoalSheet extends ConsumerStatefulWidget {
  final int year;
  final int initial;
  final bool isNew;
  const _ReadingGoalSheet({required this.year, required this.initial, required this.isNew});

  @override
  ConsumerState<_ReadingGoalSheet> createState() => _ReadingGoalSheetState();
}

class _ReadingGoalSheetState extends ConsumerState<_ReadingGoalSheet> {
  late int _goal = widget.initial;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).setReadingGoal(widget.year, _goal);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your goal. Check your connection and try again.')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.year} reading goal', style: AppTheme.serif.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              widget.isNew ? 'How many books do you want to read in ${widget.year}?' : 'Change your goal for ${widget.year}.',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 18),
            GoalStepper(goal: _goal, onChanged: (v) => setState(() => _goal = v)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.isNew ? 'Set goal' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
