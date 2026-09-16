import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/club.dart';
import '../../models/club_review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_lists_provider.dart';
import '../../theme.dart';
import '../../widgets/error_state.dart';
import '../../widgets/star_rating.dart';
import '../home/add_book_screen.dart';
import '../home/book_detail_screen.dart';

class ClubReviewsScreen extends ConsumerStatefulWidget {
  final String clubId;
  final ClubBook book;
  const ClubReviewsScreen({super.key, required this.clubId, required this.book});

  @override
  ConsumerState<ClubReviewsScreen> createState() => _ClubReviewsScreenState();
}

class _ClubReviewsScreenState extends ConsumerState<ClubReviewsScreen> {
  final _scrollCtrl = ScrollController();

  ClubReviewsArgs get _args => (clubId: widget.clubId, clubBookId: widget.book.id);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(clubReviewsProvider(_args).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmReveal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spoiler warning'),
        content: const Text("You haven't finished this book yet. Reviews may reveal plot details before you get there. View anyway?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.terra),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('View Anyway'),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(clubReviewsProvider(_args).notifier).load(override: true);
  }

  Future<void> _openMyReview(ClubReviewEntry review) async {
    if (review.bookId != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: review.bookId!)));
    } else {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AddBookScreen(
          initialTitle: widget.book.title,
          initialAuthor: widget.book.author,
          initialCoverUrl: widget.book.coverUrl,
        ),
      ));
    }
    final revealed = ref.read(clubReviewsProvider(_args)).revealed;
    ref.read(clubReviewsProvider(_args).notifier).load(override: revealed);
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authProvider).user?.id;
    final state = ref.watch(clubReviewsProvider(_args));
    final reviews = state.reviews;
    final hasLocked = reviews.any((r) => r.locked);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(widget.book.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: state.loading && reviews.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.green))
            : state.error != null && reviews.isEmpty
                ? ErrorState(message: state.error!, onRetry: () => ref.read(clubReviewsProvider(_args).notifier).load())
                : RefreshIndicator(
                    color: AppColors.green,
                    onRefresh: () => ref.read(clubReviewsProvider(_args).notifier).load(override: state.revealed),
                    child: reviews.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(40),
                                child: Text('No one has reviewed this book yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                              ),
                            ],
                          )
                        : ListView(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                        children: [
                          if (hasLocked && !state.revealed)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppColors.terraSoft, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      "You haven't finished this book — some reviews are hidden to avoid spoilers.",
                                      style: TextStyle(fontSize: 12, color: AppColors.terra, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  TextButton(onPressed: _confirmReveal, child: const Text('View Anyway')),
                                ],
                              ),
                            ),
                          ...reviews.map((review) => _ReviewCard(
                                review: review,
                                isMine: review.userId == myId,
                                onTapMine: () => _openMyReview(review),
                              )),
                          if (state.loadingMore)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2)),
                            ),
                        ],
                      ),
      ),
    ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ClubReviewEntry review;
  final bool isMine;
  final VoidCallback onTapMine;
  const _ReviewCard({required this.review, required this.isMine, required this.onTapMine});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paperSoft,
        border: Border.all(color: isMine ? AppColors.green.withValues(alpha: 0.4) : AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isMine ? '${review.name} (you)' : review.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              if (review.rating != null) StarRating(rating: review.rating!, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          if (isMine) ...[
            if (review.bookId == null)
              const Text("You haven't added this book to your shelf yet.", style: TextStyle(fontSize: 12, color: AppColors.inkSoft, fontStyle: FontStyle.italic))
            else if (review.finalReview != null && review.finalReview!.isNotEmpty)
              Text(review.finalReview!, style: const TextStyle(fontSize: 12.5, height: 1.5))
            else if (review.rating != null)
              const Text("You've rated this one but haven't written a review yet.", style: TextStyle(fontSize: 12, color: AppColors.inkSoft, fontStyle: FontStyle.italic))
            else
              const Text('No review yet.', style: TextStyle(fontSize: 12, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onTapMine,
              child: Text(
                review.bookId == null ? 'Add to shelf to review it' : 'View / edit my review',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.green),
              ),
            ),
          ] else if (review.locked)
            const Text('Hidden until you finish the book.', style: TextStyle(fontSize: 12, color: AppColors.inkSoft, fontStyle: FontStyle.italic))
          else if (review.finalReview != null && review.finalReview!.isNotEmpty)
            Text(review.finalReview!, style: const TextStyle(fontSize: 12.5, height: 1.5))
          else
            const Text('No written review.', style: TextStyle(fontSize: 12, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
