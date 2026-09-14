import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final dashboardAsync = ref.watch(dashboardProvider);
    final totalRead = dashboardAsync.asData?.value.totalRead ?? 0;

    if (user == null) return const SizedBox.shrink();

    final goalPct = user.readingGoal == 0 ? 0.0 : (totalRead / user.readingGoal).clamp(0, 1).toDouble();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
          children: [
            Text('Profile', style: AppTheme.serif.copyWith(fontSize: 20)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.green,
                    child: Text(user.initials, style: AppTheme.serif.copyWith(fontSize: 24, color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name, style: AppTheme.serif.copyWith(fontSize: 19)),
                  const SizedBox(height: 4),
                  Text('$totalRead of ${user.readingGoal} books this year', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: goalPct,
                      minHeight: 8,
                      backgroundColor: AppColors.creamDark,
                      valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FAVOURITE GENRES', style: labelCapsStyle),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: user.genres
                        .map((g) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(999)),
                              child: Text(g, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.green)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => ref.read(authProvider.notifier).logout(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: AppColors.lineStrong), borderRadius: BorderRadius.circular(10)),
                child: const Text('Switch Reader', style: TextStyle(color: AppColors.terra, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
