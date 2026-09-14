import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

final dateFieldFmt = DateFormat('yyyy-MM-dd');

class AppDateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const AppDateField({super.key, required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelCapsStyle),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.lineStrong))),
            child: Text(
              date != null ? dateFieldFmt.format(date!) : 'MM/DD/YYYY',
              style: TextStyle(fontSize: 13, color: date != null ? AppColors.ink : AppColors.lineStrong),
            ),
          ),
        ),
      ],
    );
  }
}
