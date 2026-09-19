import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme.dart';
import 'club_book_cover.dart';

/// The profile's ranked favourite books: five equal slots, filled left to
/// right with cover, rank and title, the rest shown as empty numbered slots.
class TopBooksRow extends StatelessWidget {
  final List<TopBook> books;
  const TopBooksRow({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < AppUser.maxTopBooks; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < AppUser.maxTopBooks - 1 ? 8 : 0),
              child: _Slot(rank: i + 1, book: i < books.length ? books[i] : null),
            ),
          ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  final int rank;
  final TopBook? book;
  const _Slot({required this.rank, required this.book});

  @override
  Widget build(BuildContext context) {
    final book = this.book;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: book == null
              ? Container(
                  decoration: BoxDecoration(
                    color: AppColors.creamDark.withValues(alpha: 0.5),
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text('$rank', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.lineStrong)),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, box) => ClubBookCover(
                          title: book.title,
                          coverColor: book.coverColor,
                          coverUrl: book.coverUrl,
                          width: box.maxWidth,
                          height: box.maxHeight,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      left: 3,
                      child: Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                        child: Text('$rank', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
        ),
        if (book != null) ...[
          const SizedBox(height: 4),
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, height: 1.2)),
        ],
      ],
    );
  }
}
