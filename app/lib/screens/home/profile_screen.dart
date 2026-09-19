import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_provider.dart';
import '../../providers/clubs_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme.dart';
import '../../widgets/club_image.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/reading_goal_sheet.dart';
import '../../widgets/top_books_row.dart';
import '../../widgets/user_avatar.dart';
import '../clubs/club_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'edit_top_books_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    final bytes = await picked.readAsBytes();
    final ok = await ref.read(authProvider.notifier).uploadAvatar(bytes: bytes, filename: picked.name);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    if (!ok) {
      final error = ref.read(authProvider).error ?? 'Could not upload that image';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Switch reader?',
      message: "You'll need to sign in again to get back to your shelf.",
      confirmLabel: 'Switch Reader',
      danger: false,
    );
    if (confirmed) {
      ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final dashboardAsync = ref.watch(dashboardProvider);
    final dash = dashboardAsync.asData?.value;
    final totalRead = dash?.totalRead ?? 0;

    if (user == null) return const SizedBox.shrink();

    // Same year as the stats above it (the year picked on the Stats page).
    final year = dash?.year ?? DateTime.now().year;
    final goal = user.goalFor(year);
    final goalPct = (goal == null || goal == 0) ? 0.0 : (totalRead / goal).clamp(0, 1).toDouble();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
          children: [
            Row(
              children: [
                Text('Profile', style: AppTheme.serif.copyWith(fontSize: 20)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.green),
                  label: const Text('Edit', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _uploadingAvatar
                            ? const SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                              )
                            : UserAvatar(avatarUrl: user.avatarUrl, initials: user.initials, size: 64),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name, style: AppTheme.serif.copyWith(fontSize: 19)),
                  const SizedBox(height: 4),
                  if (goal == null) ...[
                    Text('$totalRead books read in $year', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => showReadingGoalSheet(context, ref, year: year),
                      child: Text('Set your $year reading goal'),
                    ),
                  ] else ...[
                    Text(
                      year == DateTime.now().year ? '$totalRead of $goal books this year' : '$totalRead of $goal books in $year',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                    ),
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
                    const SizedBox(height: 2),
                    TextButton(
                      onPressed: () => showReadingGoalSheet(context, ref, year: year),
                      child: const Text('Edit goal', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _ProfileCard(
              title: 'TOP 5 BOOKS',
              actionLabel: user.topBooks.isEmpty ? 'Choose' : 'Edit',
              onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditTopBooksScreen())),
              child: user.topBooks.isEmpty
                  ? const Text('Pick your five favourite books to show here.', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft))
                  : TopBooksRow(books: user.topBooks),
            ),
            const SizedBox(height: 14),
            const _MyClubsCard(),
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
              onTap: _confirmLogout,
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

/// A titled card with an optional action on the right, matching the profile
/// page's other cards.
class _ProfileCard extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  const _ProfileCard({required this.title, this.actionLabel, this.onAction, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: labelCapsStyle),
              if (actionLabel != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(actionLabel!, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Every club the user is an active member of — name and image, tapping one
/// opens it. Reads the same list the Clubs tab loads at startup.
class _MyClubsCard extends ConsumerWidget {
  const _MyClubsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsState = ref.watch(clubsProvider);
    final clubs = clubsState.clubs;

    return _ProfileCard(
      title: 'MY CLUBS',
      child: clubs.isEmpty
          ? (clubsState.loading
              ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green)))
              : const Text("You're not in any clubs yet.", style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)))
          : Column(
              children: [
                for (var i = 0; i < clubs.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.line),
                  InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubDetailScreen(clubId: clubs[i].id)));
                      ref.read(clubsProvider.notifier).load();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          ClubImage(imageUrl: clubs[i].imageUrl, name: clubs[i].name, size: 40, borderRadius: 10),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              clubs[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.lineStrong),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
