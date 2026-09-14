import 'package:flutter/material.dart';

import '../theme.dart';

const genreOptions = [
  'Romance', 'Fantasy', 'Contemporary', 'Thriller', 'Mystery',
  'Sci-Fi', 'Historical', 'Horror', 'Non-fiction', 'Dark Academia',
];

class GenreChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const GenreChip({super.key, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.green : AppColors.paperSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.green : AppColors.lineStrong),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.paperSoft : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
