import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/club.dart';
import '../../providers/clubs_provider.dart';
import '../../theme.dart';
import '../../widgets/club_book_cover.dart';
import '../../widgets/club_image.dart';
import '../../widgets/error_state.dart';
import 'club_detail_screen.dart';
import 'create_club_screen.dart';

final _dateFmt = DateFormat('MMM d, yyyy');

String? _bookDateLabel(ClubBook book) {
  if (book.startDate != null && book.endDate != null) {
    return '${_dateFmt.format(book.startDate!)} – ${_dateFmt.format(book.endDate!)}';
  }
  if (book.startDate != null) return 'Started ${_dateFmt.format(book.startDate!)}';
  if (book.endDate != null) return 'Finished ${_dateFmt.format(book.endDate!)}';
  return null;
}

class ClubsListScreen extends ConsumerStatefulWidget {
  const ClubsListScreen({super.key});

  @override
  ConsumerState<ClubsListScreen> createState() => _ClubsListScreenState();
}

class _ClubsListScreenState extends ConsumerState<ClubsListScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(clubsProvider.notifier).load());
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(clubsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _respond(String clubId, bool accept) async {
    final ok = await ref.read(clubsProvider.notifier).respondToInvite(clubId, accept);
    if (!ok && mounted) {
      final error = ref.read(clubsProvider).error;
      if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clubsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateClubScreen()),
          );
          if (created == true) ref.read(clubsProvider.notifier).load();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () => ref.read(clubsProvider.notifier).load(),
          child: CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Text('Book Clubs', style: AppTheme.display.copyWith(fontSize: 22)),
                ),
              ),
              if (state.invites.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                  sliver: SliverToBoxAdapter(child: Text('INVITES', style: labelCapsStyle)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final invite = state.invites[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.paperSoft,
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(invite.clubName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                    const SizedBox(height: 2),
                                    Text('Invited by ${invite.invitedByName}', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                                  ],
                                ),
                              ),
                              TextButton(onPressed: () => _respond(invite.clubId, false), child: const Text('Decline')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                                onPressed: () => _respond(invite.clubId, true),
                                child: const Text('Join'),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: state.invites.length,
                    ),
                  ),
                ),
              ],
              if (state.loading && state.clubs.isEmpty)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.green)))
              else if (state.error != null && state.clubs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    message: state.error!,
                    onRetry: () => ref.read(clubsProvider.notifier).load(),
                  ),
                )
              else if (state.clubs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        "You're not in any book clubs yet. Start one, or ask a club owner to invite the email you signed up with.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i == state.clubs.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2)),
                          );
                        }
                        final club = state.clubs[i];
                        final book = club.currentBook;
                        return GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ClubDetailScreen(clubId: club.id)),
                            );
                            ref.read(clubsProvider.notifier).load();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.paperSoft,
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClubImage(imageUrl: club.imageUrl, name: club.name, size: 48, borderRadius: 10),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(club.name, style: AppTheme.serif.copyWith(fontSize: 16)),
                                      const SizedBox(height: 8),
                                      if (book == null)
                                        const Text('No book picked yet', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft))
                                      else
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ClubBookCover(title: book.title, coverColor: book.coverColor, coverUrl: book.coverUrl, width: 32, height: 46),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Reading: ${book.title}',
                                                    style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(book.author, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  if (_bookDateLabel(book) != null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(_bookDateLabel(book)!, style: const TextStyle(fontSize: 10, color: AppColors.lineStrong)),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 8),
                                      Text('${club.activeMembers.length} members', style: const TextStyle(fontSize: 11, color: AppColors.lineStrong)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: AppColors.lineStrong),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: state.clubs.length + (state.loadingMore ? 1 : 0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
