import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/book.dart';
import '../theme.dart';
import 'star_rating.dart';

final _dateFmt = DateFormat('MMM d, yyyy');

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const BookCard({super.key, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = Color(int.parse(book.coverColor.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.paperSoft,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: book.coverUrl != null
                  ? Image.network(
                      book.coverUrl!,
                      width: 52,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _CoverPlaceholder(color: cover, initials: book.initials),
                    )
                  : _CoverPlaceholder(color: cover, initials: book.initials),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: AppTheme.serif.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(book.author, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _FlagPill(icon: Icons.shopping_bag_outlined, label: 'Owned', active: book.purchased, activeColor: AppColors.green),
                      const SizedBox(width: 8),
                      _FlagPill(icon: Icons.menu_book_outlined, label: 'Read', active: book.read, activeColor: AppColors.terra),
                    ],
                  ),
                  if (book.read) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        StarRating(rating: book.rating ?? 0, size: 12),
                        if (book.startDate != null && book.endDate != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_dateFmt.format(book.startDate!)} - ${_dateFmt.format(book.endDate!)}',
                              style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ] else if (book.isReading) ...[
                    const SizedBox(height: 7),
                    Text('Started ${_dateFmt.format(book.startDate!)}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.terra)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final Color color;
  final String initials;
  const _CoverPlaceholder({required this.color, required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 76,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      color: color,
      child: Text(
        initials,
        textAlign: TextAlign.center,
        style: AppTheme.serif.copyWith(fontSize: 10, color: AppColors.paperSoft),
      ),
    );
  }
}

class _FlagPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;

  const _FlagPill({required this.icon, required this.label, required this.active, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.lineStrong;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
