import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// "− 40 books +" reading-goal picker, stepping by 5. Shared by the register
/// screen and the edit-profile screen.
class GoalStepper extends StatelessWidget {
  final int goal;
  final ValueChanged<int> onChanged;

  const GoalStepper({super.key, required this.goal, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepperButton(icon: Icons.remove, onTap: () => onChanged((goal - 5).clamp(5, 999))),
        Expanded(
          child: Center(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(text: '$goal ', style: GoogleFonts.spectral(fontSize: 26, color: AppColors.ink)),
                const TextSpan(text: 'books', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              ]),
            ),
          ),
        ),
        _StepperButton(icon: Icons.add, onTap: () => onChanged(goal + 5)),
      ],
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
