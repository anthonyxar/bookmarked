import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/club_bingo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_detail_provider.dart';
import '../../services/api_client.dart';
import '../../theme.dart';
import '../../widgets/bingo_cell_widget.dart';
import '../../widgets/error_state.dart';

class ClubBingoScreen extends ConsumerStatefulWidget {
  final String clubId;
  const ClubBingoScreen({super.key, required this.clubId});

  @override
  ConsumerState<ClubBingoScreen> createState() => _ClubBingoScreenState();
}

class _ClubBingoScreenState extends ConsumerState<ClubBingoScreen> {
  Future<void> _toggle(String squareId, bool currentlyCompleted) async {
    try {
      await ref.read(apiClientProvider).patch('/clubs/${widget.clubId}/bingo/squares/$squareId', body: {'completed': !currentlyCompleted});
      ref.invalidate(clubBingoProvider(widget.clubId));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authProvider).user?.id;
    final bingoAsync = ref.watch(clubBingoProvider(widget.clubId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Club Bingo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: bingoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
          error: (e, _) => ErrorState(
            message: e is ApiException ? e.message : '$e',
            onRetry: () => ref.refresh(clubBingoProvider(widget.clubId).future),
          ),
          data: (bingo) => _buildBody(bingo, myId),
        ),
      ),
    );
  }

  Widget _buildBody(ClubBingo bingo, String? myId) {
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: () => ref.refresh(clubBingoProvider(widget.clubId).future),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${bingo.completedCount} / ${bingo.squares.length} squares complete', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bingo.squares.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 6, crossAxisSpacing: 6),
                itemBuilder: (context, i) {
                  final square = bingo.squares[i];
                  return BingoCellWidget(
                    label: square.label,
                    completed: square.completed,
                    locked: square.locked,
                    editMode: false,
                    onTap: () => _toggle(square.id, square.completed),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('LEADERBOARD', style: labelCapsStyle),
            const SizedBox(height: 8),
            ...bingo.leaderboard.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final e = entry.value;
              final isMine = e.userId == myId;
              final won = e.wonAt != null;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: won ? AppColors.greenSoft : AppColors.paperSoft,
                  border: Border.all(color: isMine ? AppColors.green : AppColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: won
                          ? const Icon(Icons.emoji_events, size: 18, color: AppColors.gold)
                          : Text('#$rank', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.inkSoft)),
                    ),
                    Expanded(
                      child: Text(isMine ? '${e.name} (you)' : e.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ),
                    Text('${e.completedCount} / ${e.totalCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
