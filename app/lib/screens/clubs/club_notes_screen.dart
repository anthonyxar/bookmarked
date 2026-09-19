import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/club.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_lists_provider.dart';
import '../../providers/moderation_provider.dart';
import '../../theme.dart';
import '../../widgets/content_menu.dart';
import '../../widgets/error_state.dart';
import '../../widgets/report_dialog.dart';

final _dateFmt = DateFormat('MMM d');

class ClubNotesScreen extends ConsumerStatefulWidget {
  final String clubId;
  final ClubBook book;
  const ClubNotesScreen({super.key, required this.clubId, required this.book});

  @override
  ConsumerState<ClubNotesScreen> createState() => _ClubNotesScreenState();
}

class _ClubNotesScreenState extends ConsumerState<ClubNotesScreen> {
  final _scrollCtrl = ScrollController();

  ClubNotesArgs get _args => (clubId: widget.clubId, clubBookId: widget.book.id, isCurrent: widget.book.isCurrent);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(clubNotesProvider(_args).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final myChapter = ref.read(clubNotesProvider(_args)).myChapter;
    final chapterController = TextEditingController(text: myChapter.toString());
    final bodyController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a chapter note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: chapterController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Chapter'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyController,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Your thoughts on this chapter...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || bodyController.text.trim().isEmpty) return;
    final chapter = int.tryParse(chapterController.text.trim()) ?? myChapter;

    final ok = await ref.read(clubNotesProvider(_args).notifier).addNote(chapter, bodyController.text.trim());
    if (!ok && mounted) {
      final error = ref.read(clubNotesProvider(_args)).error ?? 'Could not save that note';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authProvider).user?.id;
    final state = ref.watch(clubNotesProvider(_args));
    // Notes by people the user has blocked are hidden (issue #34).
    final blocked = ref.watch(blockedUserIdsProvider).valueOrNull ?? const <String>{};
    final notes = state.notes.where((n) => !blocked.contains(n.userId)).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(widget.book.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: widget.book.isCurrent
          ? FloatingActionButton(
              backgroundColor: AppColors.green,
              onPressed: _addNote,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: state.loading && notes.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.green))
            : state.error != null && notes.isEmpty
                ? ErrorState(message: state.error!, onRetry: () => ref.read(clubNotesProvider(_args).notifier).load())
                : RefreshIndicator(
                    color: AppColors.green,
                    onRefresh: () => ref.read(clubNotesProvider(_args).notifier).load(),
                    child: notes.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: Text(
                                  widget.book.isCurrent
                                      ? "No notes yet. Notes only appear to others once they've reached that chapter."
                                      : 'No notes were left for this book.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.inkSoft),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                            itemCount: notes.length + (state.loadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == notes.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2)),
                                );
                              }
                              final note = notes[i];
                              final isMine = note.userId == myId;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.paperSoft,
                                  border: Border.all(color: isMine ? AppColors.green.withValues(alpha: 0.4) : AppColors.line),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Chapter ${note.chapter} · ${note.authorName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_dateFmt.format(note.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
                                            if (!isMine)
                                              IconButton(
                                                tooltip: 'Report or block',
                                                visualDensity: VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 24),
                                                icon: const Icon(Icons.more_horiz, size: 18, color: AppColors.inkSoft),
                                                onPressed: () => showContentMenu(
                                                  context,
                                                  ref,
                                                  reportLabel: 'Report this note',
                                                  onReport: () => showReportDialog(
                                                    context,
                                                    ref,
                                                    type: ReportType.note,
                                                    subject: 'this note',
                                                    clubId: widget.clubId,
                                                    targetId: note.id,
                                                    targetUserId: note.userId,
                                                    bookId: widget.book.id,
                                                    snapshot: note.body,
                                                  ),
                                                  blockUserId: note.userId,
                                                  blockName: note.authorName,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(note.body, style: const TextStyle(fontSize: 12.5, height: 1.5)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}
