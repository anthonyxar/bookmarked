import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/challenge.dart';
import '../../providers/challenges_provider.dart';
import '../../theme.dart';
import '../../widgets/error_state.dart';

const _azLetters = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

const _challengeColors = {
  'genre_explorer': AppColors.green,
  'chunky_reads': AppColors.terra,
  'five_star_shelf': AppColors.gold,
};

const _challengeIcons = {
  'genre_explorer': Icons.menu_book_outlined,
  'chunky_reads': Icons.auto_stories_outlined,
  'five_star_shelf': Icons.star_rounded,
};

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(challengesProvider);
    final selectedYear = ref.watch(challengesYearProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () async => ref.invalidate(challengesProvider),
          child: challengesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
            error: (e, _) => ListView(children: [
              Padding(
                padding: const EdgeInsets.all(40),
                child: ErrorState(message: '$e', onRetry: () => ref.invalidate(challengesProvider)),
              ),
            ]),
            data: (data) => ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('Yearly Challenges', style: AppTheme.serif.copyWith(fontSize: 20))),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => ref.read(challengesYearProvider.notifier).state = selectedYear - 1,
                          icon: const Icon(Icons.chevron_left, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text('$selectedYear', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        IconButton(
                          onPressed: selectedYear >= DateTime.now().year
                              ? null
                              : () => ref.read(challengesYearProvider.notifier).state = selectedYear + 1,
                          icon: const Icon(Icons.chevron_right, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  "Tracked automatically from what's marked read on your shelf.",
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),
                for (final challenge in data.challenges) ...[
                  if (challenge.id == 'az_titles') _AzChallengeCard(challenge: challenge) else _CompactChallengeCard(challenge: challenge),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoTag extends StatelessWidget {
  const _AutoTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(999)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync_rounded, size: 10, color: AppColors.green),
          SizedBox(width: 3),
          Text('AUTO-TRACKED', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: AppColors.green)),
        ],
      ),
    );
  }
}

class _AzChallengeCard extends StatelessWidget {
  final Challenge challenge;
  const _AzChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final letters = challenge.letters ?? List.filled(26, false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.title, style: AppTheme.serif.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(challenge.description, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _AutoTag(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: challenge.pct,
                    minHeight: 8,
                    backgroundColor: AppColors.creamDark,
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${challenge.progress} / ${challenge.goal}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 26,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 5),
            itemBuilder: (context, i) {
              final done = letters[i];
              return Container(
                decoration: BoxDecoration(
                  color: done ? AppColors.green : Colors.transparent,
                  border: done ? null : Border.all(color: AppColors.lineStrong, width: 1.3),
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: Text(
                  _azLetters[i],
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: done ? AppColors.paperSoft : AppColors.lineStrong),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CompactChallengeCard extends StatelessWidget {
  final Challenge challenge;
  const _CompactChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final color = _challengeColors[challenge.id] ?? AppColors.green;
    final icon = _challengeIcons[challenge.id] ?? Icons.flag_outlined;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(challenge.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('${challenge.progress} / ${challenge.goal}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(challenge.description, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: challenge.pct,
                    minHeight: 7,
                    backgroundColor: AppColors.creamDark,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
