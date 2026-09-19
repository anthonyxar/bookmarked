import 'package:flutter/material.dart';

import '../theme.dart';

/// A segmented Yes/No control. Used in place of a Material [Switch] for
/// boolean review fields — plain tappable containers, the same pattern
/// used for genre chips and filter tabs elsewhere in the app.
class YesNoToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const YesNoToggle({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
      // Label above the control, not beside it: the review screens put two of
      // these side by side, so each only gets a bit under half the screen and
      // a label + control row overflowed on real phones.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: AppColors.creamDark, borderRadius: BorderRadius.circular(999)),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _segment(context, 'No', !value),
                _segment(context, 'Yes', value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String text, bool active) {
    final isYes = text == 'Yes';
    return GestureDetector(
      onTap: () => onChanged(isYes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.inkSoft),
        ),
      ),
    );
  }
}
