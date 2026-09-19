import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/moderation_provider.dart';
import '../../theme.dart';
import '../../utils/app_functions.dart';
import '../../widgets/confirm_dialog.dart';

final _whenFmt = DateFormat('MMM d, h:mm a');

class _OpenReport {
  final String id;
  final String type;
  final String reason;
  final String details;
  final String snapshot;
  final String clubId;
  final String? targetUserId;
  final DateTime? createdAt;

  _OpenReport(this.id, Map<String, dynamic> data)
      : type = data['type'] as String? ?? '?',
        reason = data['reason'] as String? ?? '?',
        details = data['details'] as String? ?? '',
        snapshot = data['snapshot'] as String? ?? '',
        clubId = data['clubId'] as String? ?? '',
        targetUserId = data['targetUserId'] as String?,
        createdAt = (data['createdAt'] as Timestamp?)?.toDate();

  String get reasonLabel {
    for (final r in ReportReason.values) {
      if (r.name == reason) return r.label;
    }
    return reason;
  }
}

/// Open reports from club members, with the moderator actions the
/// `resolveReport` function offers. Only reachable by users with the `admin`
/// claim (see docs/moderation.md); the rules and the function enforce that
/// regardless of what the UI shows.
class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  List<_OpenReport>? _reports;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final snap = await ref.read(firestoreProvider).collection('reports').where('status', isEqualTo: 'open').get();
      final reports = snap.docs.map((d) => _OpenReport(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      if (mounted) setState(() => _reports = reports);
    } catch (e) {
      if (mounted) setState(() => _error = e is FirebaseException ? (e.message ?? 'Could not load reports') : 'Could not load reports');
    }
  }

  Future<void> _apply(_OpenReport report, String action, {String? confirm, String? confirmLabel}) async {
    if (confirm != null) {
      final ok = await confirmDialog(context, title: confirmLabel ?? 'Are you sure?', message: confirm, confirmLabel: confirmLabel ?? 'Confirm');
      if (!ok || !mounted) return;
    }
    setState(() => _busy.add(report.id));
    String message;
    try {
      await appFunctions.httpsCallable('resolveReport').call({'reportId': report.id, 'action': action});
      _reports?.removeWhere((r) => r.id == report.id);
      message = 'Done';
    } on FirebaseFunctionsException catch (e) {
      message = e.message ?? 'Could not apply that action';
    } catch (_) {
      message = 'Could not apply that action';
    }
    if (!mounted) return;
    setState(() => _busy.remove(report.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final reports = _reports;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Moderation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: reports == null
            ? (_error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft)),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator(color: AppColors.green)))
            : RefreshIndicator(
                color: AppColors.green,
                onRefresh: _load,
                child: reports.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(40),
                            child: Text('No open reports.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                        itemCount: reports.length,
                        itemBuilder: (context, i) => _reportCard(reports[i]),
                      ),
              ),
      ),
    );
  }

  Widget _reportCard(_OpenReport r) {
    final busy = _busy.contains(r.id);
    final canRemoveContent = r.type == 'note' || r.type == 'club';
    final canRemoveMember = r.targetUserId != null && r.type != 'club';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${r.type.toUpperCase()} · ${r.reasonLabel}', style: labelCapsStyle),
              if (r.createdAt != null) Text(_whenFmt.format(r.createdAt!), style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
            ],
          ),
          if (r.snapshot.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.snapshot, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.4)),
          ],
          if (r.details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reporter says: ${r.details}', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 6),
          Text('Club ${r.clubId}${r.targetUserId != null ? ' · user ${r.targetUserId}' : ''}', style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          if (busy)
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(onPressed: () => _apply(r, 'dismiss'), child: const Text('Dismiss')),
                if (canRemoveContent)
                  OutlinedButton(
                    onPressed: () => _apply(r, 'removeContent',
                        confirm: r.type == 'club'
                            ? "This clears the club's image and description and renames it. Continue?"
                            : 'This deletes the note for everyone. Continue?',
                        confirmLabel: 'Remove content'),
                    child: const Text('Remove content'),
                  ),
                if (canRemoveMember)
                  OutlinedButton(
                    onPressed: () => _apply(r, 'removeMember',
                        confirm: 'This removes them from the club. Continue?', confirmLabel: 'Remove member'),
                    child: const Text('Remove member'),
                  ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.terra),
                  onPressed: () => _apply(r, 'suspendUser',
                      confirm: 'This disables their account everywhere and signs them out. Continue?', confirmLabel: 'Suspend user'),
                  child: const Text('Suspend user'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
