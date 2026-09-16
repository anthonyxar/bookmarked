import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/book.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_detail_provider.dart';
import '../../providers/books_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_client.dart';
import '../../theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_state.dart';
import '../../widgets/star_rating.dart';
import 'edit_book_screen.dart';
import 'edit_review_screen.dart';

final _dateFmt = DateFormat('MMM d, yyyy');

Widget _coverPlaceholder(Color color, String initials) {
  return Container(
    width: 84,
    height: 122,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    color: color,
    child: Text(initials, textAlign: TextAlign.center, style: AppTheme.serif.copyWith(fontSize: 14, color: Colors.white)),
  );
}

class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  Future<void> _toggle(String field, bool value) async {
    try {
      await ref.read(apiClientProvider).patch('/books/${widget.bookId}', body: {field: value});
      ref.invalidate(bookDetailProvider(widget.bookId));
      ref.invalidate(dashboardProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _setTimesRead(int value) async {
    if (value < 0) return;
    try {
      await ref.read(apiClientProvider).patch('/books/${widget.bookId}', body: {'times_read': value});
      ref.invalidate(bookDetailProvider(widget.bookId));
      ref.invalidate(dashboardProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openEditReview(Book book) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditReviewScreen(book: book)),
    );
    if (saved == true) ref.invalidate(bookDetailProvider(widget.bookId));
  }

  Future<void> _openEditBook(Book book) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditBookScreen(book: book)),
    );
    if (saved == true) ref.invalidate(bookDetailProvider(widget.bookId));
  }

  Future<void> _confirmDelete(Book book) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete book?',
      message: 'This permanently removes "${book.title}" from your shelf, including its review. This can\'t be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    final ok = await ref.read(booksProvider.notifier).delete(widget.bookId);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(dashboardProvider);
      Navigator.of(context).pop();
    } else {
      final error = ref.read(booksProvider).error ?? 'Could not delete this book';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.bookId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Book Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        actions: [
          if (bookAsync.value != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'edit_book') _openEditBook(bookAsync.value!);
                if (value == 'edit_review') _openEditReview(bookAsync.value!);
                if (value == 'delete') _confirmDelete(bookAsync.value!);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit_book', child: Text('Edit Book')),
                const PopupMenuItem(value: 'edit_review', child: Text('Edit Review')),
                const PopupMenuItem(value: 'delete', child: Text('Delete Book', style: TextStyle(color: AppColors.terra))),
              ],
            ),
        ],
      ),
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
        error: (e, _) => ErrorState(
          message: e is ApiException ? e.message : '$e',
          onRetry: () => ref.invalidate(bookDetailProvider(widget.bookId)),
        ),
        data: _buildBody,
      ),
    );
  }

  Widget _buildBody(Book book) {
    final cover = Color(int.parse(book.coverColor.replaceFirst('#', '0xFF')));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: book.coverUrl != null
                    ? Image.network(
                        book.coverUrl!,
                        width: 84,
                        height: 122,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _coverPlaceholder(cover, book.initials),
                      )
                    : _coverPlaceholder(cover, book.initials),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: AppTheme.serif.copyWith(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(book.author, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                    const SizedBox(height: 6),
                    Text(
                      book.series != null && book.series!.isNotEmpty
                          ? '${book.series}${book.bookNo != null ? " · Book ${book.bookNo}" : ""}'
                          : 'Standalone',
                      style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _TogglePill(
                          label: book.purchased ? 'Owned' : 'Not Purchased',
                          active: book.purchased,
                          activeColor: AppColors.green,
                          onTap: () => _toggle('purchased', !book.purchased),
                        ),
                        const SizedBox(width: 6),
                        _TogglePill(
                          label: book.read ? 'Read' : 'Unread',
                          active: book.read,
                          activeColor: AppColors.terra,
                          onTap: () => _toggle('read', !book.read),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(book: book, onTimesReadChanged: _setTimesRead),
          if (book.read) ...[
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  const Text('OVERALL RATING', style: labelCapsStyle),
                  const SizedBox(height: 8),
                  StarRating(rating: book.rating ?? 0, size: 26),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CategoryRatings(book: book),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _StatBadge(label: 'ENJOYED IT?', value: _yesNo(book.enjoyed), color: AppColors.green, bg: AppColors.greenSoft)),
                const SizedBox(width: 10),
                Expanded(child: _StatBadge(label: 'READ AGAIN?', value: _yesNo(book.readAgain), color: AppColors.terra, bg: AppColors.terraSoft)),
              ],
            ),
            const SizedBox(height: 20),
            _ThoughtsSection(book: book),
            if (book.favoriteCharacters.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('FAVOURITE CHARACTERS', style: labelCapsStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: book.favoriteCharacters
                    .map((c) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.creamDark, borderRadius: BorderRadius.circular(999)),
                          child: Text(c, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
            ],
            if (book.notableScenes.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('NOTABLE SCENES', style: labelCapsStyle),
              const SizedBox(height: 8),
              ...book.notableScenes.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(s, style: const TextStyle(fontSize: 12, height: 1.4))),
                      ],
                    ),
                  )),
            ],
            if (book.trope != null && book.trope!.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('TROPE', style: labelCapsStyle),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(6)),
                child: Text(book.trope!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
            if (book.finalReview != null && book.finalReview!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Final Review', style: AppTheme.serif.copyWith(fontSize: 15)),
              const Divider(color: AppColors.line, height: 18),
              Text(book.finalReview!, style: const TextStyle(fontSize: 12.5, height: 1.6)),
            ],
            const SizedBox(height: 20),
            const Text('FAVOURITE QUOTES', style: labelCapsStyle),
            const SizedBox(height: 8),
            if (book.quotes.isEmpty)
              const Text('No quotes saved for this one yet.', style: TextStyle(fontSize: 12, color: AppColors.lineStrong, fontStyle: FontStyle.italic))
            else
              ...book.quotes.map((q) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.gold, width: 2))),
                    child: Text(q, style: AppTheme.serif.copyWith(fontSize: 13, fontStyle: FontStyle.italic, height: 1.5)),
                  )),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const Text(
                    "Write your review once you've finished this one — ratings, thoughts, quotes and all.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => _openEditReview(book),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.green, side: const BorderSide(color: AppColors.green)),
                    child: const Text('Write a Review'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _yesNo(bool? v) => v == true ? 'Yes' : v == false ? 'No' : '—';
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _TogglePill({required this.label, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.14) : AppColors.creamDark,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? activeColor.withValues(alpha: 0.4) : AppColors.line),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? activeColor : AppColors.inkSoft)),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Book book;
  final ValueChanged<int> onTimesReadChanged;
  const _InfoCard({required this.book, required this.onTimesReadChanged});

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, color: AppColors.inkSoft, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        );

    final timesReadCell = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TIMES READ', style: TextStyle(fontSize: 9, color: AppColors.inkSoft, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text('${book.timesRead}', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: book.timesRead > 0 ? () => onTimesReadChanged(book.timesRead - 1) : null,
                child: Icon(Icons.remove_circle_outline, size: 15, color: book.timesRead > 0 ? AppColors.inkSoft : AppColors.line),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onTimesReadChanged(book.timesRead + 1),
                child: const Icon(Icons.add_circle_outline, size: 15, color: AppColors.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(children: [cell('GENRE', book.genre ?? '—'), cell('PUBLISHED', book.published ?? '—')]),
          const SizedBox(height: 10),
          Row(children: [cell('PAGES', book.pages != null ? '${book.pages} pages' : '—'), timesReadCell]),
          const SizedBox(height: 10),
          Row(children: [
            cell('STARTED', book.startDate != null ? _dateFmt.format(book.startDate!) : '—'),
            cell('FINISHED', book.endDate != null ? _dateFmt.format(book.endDate!) : (book.read ? '—' : 'In progress')),
          ]),
        ],
      ),
    );
  }
}

class _CategoryRatings extends StatelessWidget {
  final Book book;
  const _CategoryRatings({required this.book});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Cover Design', book.ratingCover),
      ('Writing Style', book.ratingWriting),
      ('Story & Plot', book.ratingPlot),
      ('Characters', book.ratingCharacters),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.$1, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      StarRating(rating: r.$2 ?? 0, size: 14),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatBadge({required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.85), letterSpacing: 0.4)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _ThoughtsSection extends StatelessWidget {
  final Book book;
  const _ThoughtsSection({required this.book});

  @override
  Widget build(BuildContext context) {
    Widget block(String q, String? a) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.inkSoft)),
              const SizedBox(height: 4),
              Text(a?.isNotEmpty == true ? a! : '—', style: const TextStyle(fontSize: 12.5, height: 1.5)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thoughts', style: AppTheme.serif.copyWith(fontSize: 15)),
        const Divider(color: AppColors.line, height: 18),
        block('What did you like the most?', book.likedMost),
        block('What did you like the least?', book.likedLeast),
        block('How did this book make you feel?', book.feel),
      ],
    );
  }
}
