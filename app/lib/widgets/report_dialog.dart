import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/moderation_provider.dart';
import '../theme.dart';

/// Asks why, then files a report about [subject] ("this note", a member's
/// name...) with the moderators. [snapshot] is a copy of the content as it
/// is now, so a report still makes sense if it's later edited or deleted.
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required ReportType type,
  required String subject,
  required String clubId,
  required String targetId,
  String? targetUserId,
  String? bookId,
  String snapshot = '',
}) async {
  final input = await showDialog<({ReportReason reason, String details})>(
    context: context,
    builder: (_) => _ReportDialog(subject: subject),
  );
  if (input == null) return;

  final result = await ref.read(moderationServiceProvider).report(
        type: type,
        clubId: clubId,
        targetId: targetId,
        targetUserId: targetUserId,
        bookId: bookId,
        reason: input.reason,
        details: input.details,
        snapshot: snapshot,
      );
  if (!context.mounted) return;
  final message = switch (result) {
    ReportResult.sent => "Thanks, we'll take a look.",
    ReportResult.alreadyReported => "You've already reported this — we have it.",
    ReportResult.failed => 'Could not send that report. Check your connection and try again.',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _ReportDialog extends StatefulWidget {
  final String subject;
  const _ReportDialog({required this.subject});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  ReportReason? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report ${widget.subject}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("What's wrong with it?", style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: reason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.green,
                      title: Text(reason.label, style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: ModerationService.maxDetails,
              decoration: const InputDecoration(hintText: 'Anything else we should know? (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.terra),
          onPressed: _reason == null ? null : () => Navigator.pop(context, (reason: _reason!, details: _details.text)),
          child: const Text('Send report'),
        ),
      ],
    );
  }
}
