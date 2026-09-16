import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
                  if (book.pages != null || book.timesRead > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (book.pages != null) ...[
                          const Icon(Icons.menu_book_outlined, size: 11, color: AppColors.lineStrong),
                          const SizedBox(width: 3),
                          Text('${book.pages} pages', style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                        ],
                        if (book.pages != null && book.timesRead > 0) const SizedBox(width: 10),
                        if (book.timesRead > 0) ...[
                          const Icon(Icons.replay_rounded, size: 11, color: AppColors.lineStrong),
                          const SizedBox(width: 3),
                          Text('Read ${book.timesRead}×', style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                        ],
                      ],
                    ),
                  ],
                  if (!book.purchased) ...[
                    const SizedBox(height: 8),
                    _AmazonLink(book: book),
                  ],
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
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusRail(purchased: book.purchased, read: book.read),
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

class _AmazonLink extends StatelessWidget {
  final Book book;
  const _AmazonLink({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.https('www.amazon.com', '/s', {'k': '${book.title} ${book.author}'}),
        mode: LaunchMode.externalApplication,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.open_in_new_rounded, size: 12, color: AppColors.gold),
          SizedBox(width: 3),
          Text('Find on Amazon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.gold)),
        ],
      ),
    );
  }
}

/// Two fixed status dots shown on every shelf card: ownership (green owned /
/// terra not-owned) and read progress (green read / orange to-be-read /
/// outline when not owned). Always in the same spot so a whole shelf scans
/// at a glance — see the "Book Owned and Read Status" design canvas.
class _StatusRail extends StatelessWidget {
  final bool purchased;
  final bool read;
  const _StatusRail({required this.purchased, required this.read});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusDot(
          filled: true,
          color: purchased ? AppColors.green : AppColors.terra,
          icon: purchased ? Icons.shopping_bag_outlined : Icons.shopping_cart_outlined,
          iconColor: Colors.white,
          tooltip: purchased ? 'Owned' : 'Not owned',
        ),
        const SizedBox(height: 6),
        if (read)
          const _StatusDot(filled: true, color: AppColors.green, icon: Icons.check, iconColor: Colors.white, tooltip: 'Read')
        else if (purchased)
          _StatusDot(filled: true, color: AppColors.orange, icon: Icons.schedule, iconColor: AppColors.ink, tooltip: 'To be read')
        else
          const _StatusDot(filled: false, color: AppColors.lineStrong, icon: Icons.schedule, iconColor: AppColors.lineStrong, tooltip: 'Not read'),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool filled;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String tooltip;
  const _StatusDot({required this.filled, required this.color, required this.icon, required this.iconColor, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: color, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 12, color: iconColor),
      ),
    );
  }
}
