import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/bracket.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bracket_provider.dart';
import '../../services/api_client.dart';
import '../../theme.dart';
import '../../widgets/error_state.dart';
import '../../widgets/star_rating.dart';

const _roundLabels = {
  'wildcard': 'Wildcard Round',
  'quarterfinal': 'Quarterfinals',
  'semifinal': 'Semifinals',
  'final': 'Grand Final',
};
const _roundOrder = ['wildcard', 'quarterfinal', 'semifinal', 'final'];

class BracketScreen extends ConsumerStatefulWidget {
  const BracketScreen({super.key});

  @override
  ConsumerState<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends ConsumerState<BracketScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(bracketProvider.notifier).load());
  }

  Future<void> _pickFavorite(int month) async {
    final books = await _fetchReadBooks();
    if (!mounted) return;
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mark a book as read first to pick a favourite.')));
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.paperSoft,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        expand: false,
        builder: (context, scrollController) => ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: books.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line),
          itemBuilder: (context, i) {
            final b = books[i];
            final color = Color(int.parse((b['cover_color'] as String).replaceFirst('#', '0xFF')));
            return ListTile(
              onTap: () => Navigator.pop(context, b),
              leading: Container(width: 32, height: 46, color: color),
              title: Text(b['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(b['author'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          },
        ),
      ),
    );
    if (picked != null) {
      await ref.read(bracketProvider.notifier).setFavorite(month, picked['id'] as String);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReadBooks() async {
    try {
      final json = await ref.read(apiClientProvider).get('/books', query: {'filter': 'read', 'sort': 'end_date', 'limit': '200'});
      return ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
    } on ApiException {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bracketProvider);
    final bracket = state.bracket;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Book of the Year Bracket', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: bracket == null
            ? (state.error != null
                ? ErrorState(message: state.error!, onRetry: () => ref.read(bracketProvider.notifier).load())
                : const Center(child: CircularProgressIndicator(color: AppColors.green)))
            : RefreshIndicator(
                color: AppColors.green,
                onRefresh: () => ref.read(bracketProvider.notifier).load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monthly Favourites', style: AppTheme.serif.copyWith(fontSize: 17)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => ref.read(bracketProvider.notifier).load(year: state.selectedYear - 1),
                              icon: const Icon(Icons.chevron_left, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Text('${state.selectedYear}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            IconButton(
                              onPressed: state.selectedYear >= DateTime.now().year
                                  ? null
                                  : () => ref.read(bracketProvider.notifier).load(year: state.selectedYear + 1),
                              icon: const Icon(Icons.chevron_right, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Pick your favourite read from each month, then let them face off.",
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (context, i) => _MonthTile(favorite: bracket.favorites[i], onTap: () => _pickFavorite(i + 1)),
                    ),
                    if (!bracket.isComplete) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${bracket.monthsSet} / 12 months picked', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            const SizedBox(height: 6),
                            const Text(
                              'Pick a favourite for every month to unlock the bracket.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: bracket.monthsSet / 12,
                                minHeight: 7,
                                backgroundColor: AppColors.creamDark,
                                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      for (final round in _roundOrder) ...[
                        Text(_roundLabels[round]!, style: AppTheme.serif.copyWith(fontSize: 17)),
                        const SizedBox(height: 10),
                        for (final match in bracket.byRound(round)) ...[
                          _MatchCard(match: match, onPick: (bookId) => ref.read(bracketProvider.notifier).setMatchWinner(match.id, bookId)),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 10),
                      ],
                      if (bracket.champion != null) _ChampionCard(book: bracket.champion!),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  final BracketFavorite favorite;
  final VoidCallback onTap;
  const _MonthTile({required this.favorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMM').format(DateTime(2000, favorite.month));
    final book = favorite.book;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.paperSoft,
          border: Border.all(color: book != null ? AppColors.green.withValues(alpha: 0.4) : AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(monthName.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.inkSoft, letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Expanded(
              child: book == null
                  ? const Center(child: Icon(Icons.add_circle_outline, size: 18, color: AppColors.lineStrong))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Color(int.parse(book.coverColor.replaceFirst('#', '0xFF'))),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(book.title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final BracketMatch match;
  final ValueChanged<String> onPick;
  const _MatchCard({required this.match, required this.onPick});

  @override
  Widget build(BuildContext context) {
    if (!match.isReady) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.paperSoft.withValues(alpha: 0.5), border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
        child: const Text('Waiting on an earlier round to be decided', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
      );
    }
    return Container(
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _MatchPick(book: match.bookA!, isWinner: match.winnerId == match.bookA!.id, hasWinner: match.winnerId != null, onTap: () => onPick(match.bookA!.id)),
          const Divider(height: 1, color: AppColors.line),
          _MatchPick(book: match.bookB!, isWinner: match.winnerId == match.bookB!.id, hasWinner: match.winnerId != null, onTap: () => onPick(match.bookB!.id)),
        ],
      ),
    );
  }
}

class _MatchPick extends StatelessWidget {
  final BracketBook book;
  final bool isWinner;
  final bool hasWinner;
  final VoidCallback onTap;
  const _MatchPick({required this.book, required this.isWinner, required this.hasWinner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dimmed = hasWinner && !isWinner;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        color: isWinner ? AppColors.greenSoft : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 24,
              height: 34,
              decoration: BoxDecoration(
                color: Color(int.parse(book.coverColor.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: dimmed ? AppColors.inkSoft : AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(book.author, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (book.rating != null) StarRating(rating: book.rating!, size: 11),
            const SizedBox(width: 8),
            if (isWinner)
              const Icon(Icons.check_circle, size: 18, color: AppColors.green)
            else
              Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.lineStrong),
          ],
        ),
      ),
    );
  }
}

class _ChampionCard extends StatelessWidget {
  final BracketBook book;
  const _ChampionCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        border: Border.all(color: AppColors.gold, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_outlined, size: 26, color: AppColors.gold),
          const SizedBox(height: 6),
          Text('${DateTime.now().year} CHAMPION', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.gold)),
          const SizedBox(height: 10),
          Container(
            width: 64,
            height: 92,
            decoration: BoxDecoration(
              color: Color(int.parse(book.coverColor.replaceFirst('#', '0xFF'))),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))],
            ),
          ),
          const SizedBox(height: 10),
          Text(book.title, style: AppTheme.serif.copyWith(fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(book.author, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
