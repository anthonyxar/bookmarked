import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/moderation_provider.dart';
import '../theme.dart';
import 'confirm_dialog.dart';

/// What you can do about someone else's content: report it, and (when the
/// author is known) block them. Shown from a "more" button on notes, reviews
/// and member chips.
Future<void> showContentMenu(
  BuildContext context,
  WidgetRef ref, {
  required String reportLabel,
  required VoidCallback onReport,
  String? blockUserId,
  String? blockName,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.paperSoft,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: AppColors.terra),
            title: Text(reportLabel),
            onTap: () => Navigator.pop(sheetContext, 'report'),
          ),
          if (blockUserId != null)
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.terra),
              title: Text('Block ${blockName ?? 'this person'}'),
              onTap: () => Navigator.pop(sheetContext, 'block'),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'report') onReport();
  if (choice == 'block' && blockUserId != null) {
    await confirmAndBlock(context, ref, userId: blockUserId, name: blockName ?? 'this person');
  }
}

/// Confirms, then blocks [userId]. Their notes and reviews disappear for you
/// straight away, and they can no longer invite you to a club.
Future<void> confirmAndBlock(BuildContext context, WidgetRef ref, {required String userId, required String name}) async {
  final confirmed = await confirmDialog(
    context,
    title: 'Block $name?',
    message: "You won't see their notes or reviews, and they won't be able to invite you to clubs. "
        'You can unblock them any time from your profile.',
    confirmLabel: 'Block',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(moderationServiceProvider).block(userId);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Blocked $name')));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not block them. Try again.')));
    }
  }
}
