import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/user_avatar.dart';

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
