import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/club.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_detail_provider.dart';
import '../../providers/clubs_provider.dart';
import '../../theme.dart';
import '../../utils/image_validation.dart';
import '../../widgets/club_image.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/date_field.dart';
import '../../widgets/error_state.dart';
import '../../widgets/switch_tile.dart';
import '../../widgets/user_avatar.dart';
import 'club_bingo_screen.dart';
import 'club_book_picker_screen.dart';
import 'club_history_screen.dart';
import 'club_manage_screen.dart';
import 'club_notes_screen.dart';
import 'club_reviews_screen.dart';

final _dateFmt = DateFormat('MMM d, yyyy');

class ClubDetailScreen extends ConsumerStatefulWidget {
  final String clubId;
  const ClubDetailScreen({super.key, required this.clubId});

  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen> {
  bool _uploadingImage = false;

  Future<void> _reload() => ref.refresh(clubDetailProvider(widget.clubId).future);

  Future<void> _pickClubImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final validationError = imageValidationError(picked.name, bytes.length);
    if (validationError != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      final storageRef = FirebaseStorage.instance.ref('clubImages/${widget.clubId}');
      await storageRef.putData(bytes, SettableMetadata(contentType: contentTypeForFilename(picked.name)));
      final url = await storageRef.getDownloadURL();
      final ok = await ref.read(clubsProvider.notifier).updateClub(widget.clubId, imageUrl: url);
      if (!mounted) return;
      if (ok) {
        _reload();
      } else {
        final error = ref.read(clubsProvider).error ?? 'Could not update the club image';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not upload that image')));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _updateProgress({int? chapter, bool? finished}) async {
    final ok = await ref.read(clubsProvider.notifier).updateMyProgress(widget.clubId, currentChapter: chapter, finished: finished);
    if (!mounted) return;
    if (ok) {
      _reload();
    } else {
      final error = ref.read(clubsProvider).error ?? 'Could not update your progress';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _editDates(ClubBook book) async {
    DateTime? startDate = book.startDate;
    DateTime? endDate = book.endDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reading dates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppDateField(
                label: 'Started',
                date: startDate,
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => startDate = picked);
                },
              ),
              const SizedBox(height: 14),
              AppDateField(
                label: 'Finished',
                date: endDate,
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => endDate = picked);
                },
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
      ),
    );

    if (saved != true) return;

    final ok = await ref.read(clubsProvider.notifier).updateCurrentBookDates(widget.clubId, startDate: startDate, endDate: endDate);
    if (!mounted) return;
    if (ok) {
      _reload();
    } else {
      final error = ref.read(clubsProvider).error ?? 'Could not update those dates';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _invite() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite a member'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Their Bookmarked email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;

    final ok = await ref.read(clubsProvider.notifier).inviteMember(widget.clubId, email);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite sent')));
    } else {
      final error = ref.read(clubsProvider).error ?? 'Could not send that invite';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _leaveClub() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Leave club?',
      message: "You'll lose access to this club's notes, reviews, and bingo card unless you're invited back.",
      confirmLabel: 'Leave',
    );
    if (!confirmed) return;
    final ok = await ref.read(clubsProvider.notifier).leaveClub(widget.clubId);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(clubsProvider).error ?? 'Could not leave the club';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _deleteClub() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete club?',
      message: 'This permanently deletes the club for every member, including its books, notes, reviews, and bingo card. This can\'t be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    final ok = await ref.read(clubsProvider.notifier).deleteClub(widget.clubId);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(clubsProvider).error ?? 'Could not delete the club';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authProvider).user?.id;
    final clubAsync = ref.watch(clubDetailProvider(widget.clubId));
    final club = clubAsync.value;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(club?.name ?? 'Book Club', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        actions: [
          if (club != null && club.canManage)
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: 'Manage',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubManageScreen(clubId: widget.clubId)));
                _reload();
              },
            ),
          if (club != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'leave') _leaveClub();
                if (value == 'delete') _deleteClub();
              },
              itemBuilder: (context) => [
                if (club.myRole == 'owner')
                  const PopupMenuItem(value: 'delete', child: Text('Delete club', style: TextStyle(color: AppColors.terra)))
                else
                  const PopupMenuItem(value: 'leave', child: Text('Leave club', style: TextStyle(color: AppColors.terra))),
              ],
            ),
        ],
      ),
      body: clubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
        error: (e, _) => ErrorState(message: '$e', onRetry: _reload),
        data: (club) => _buildBody(club, myId),
      ),
    );
  }

  Widget _buildBody(Club club, String? myId) {
    final me = myId != null ? club.memberById(myId) : null;
    final book = club.currentBook;

    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: _reload,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: club.canManage && !_uploadingImage ? _pickClubImage : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _uploadingImage
                        ? const SizedBox(
                            width: 84,
                            height: 84,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                          )
                        : ClubImage(imageUrl: club.imageUrl, name: club.name, size: 84),
                    if (club.canManage)
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
            ),
            const SizedBox(height: 16),
            if (club.description != null && club.description!.isNotEmpty) ...[
              Text(club.description!, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.5)),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${club.activeMembers.length} MEMBERS', style: labelCapsStyle),
                if (club.canManage)
                  GestureDetector(
                    onTap: _invite,
                    child: const Text('+ Invite', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: club.activeMembers
                  .map((m) => Container(
                        padding: const EdgeInsets.only(left: 4, right: 10, top: 4, bottom: 4),
                        decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(avatarUrl: m.avatarUrl, initials: m.initials, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              m.canManage ? '${m.name} · ${m.role}' : m.name,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
              child: book == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No book picked yet', style: TextStyle(fontWeight: FontWeight.w700)),
                        if (club.canManage) ...[
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubBookPickerScreen(clubId: widget.clubId)));
                              _reload();
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.green, side: const BorderSide(color: AppColors.green)),
                            child: const Text('Pick a Book'),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (book.coverUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  book.coverUrl!,
                                  width: 52,
                                  height: 76,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(width: 52, height: 76),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CURRENTLY READING', style: labelCapsStyle),
                                  const SizedBox(height: 4),
                                  Text(book.title, style: AppTheme.serif.copyWith(fontSize: 17)),
                                  Text(book.author, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                                  if (book.startDate != null || book.endDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      book.startDate != null && book.endDate != null
                                          ? '${_dateFmt.format(book.startDate!)} – ${_dateFmt.format(book.endDate!)}'
                                          : book.startDate != null
                                              ? 'Started ${_dateFmt.format(book.startDate!)}'
                                              : 'Finished ${_dateFmt.format(book.endDate!)}',
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.lineStrong),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (club.canManage)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    onPressed: () async {
                                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubBookPickerScreen(clubId: widget.clubId)));
                                      _reload();
                                    },
                                    child: const Text('Change'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    onPressed: () => _editDates(book),
                                    child: const Text('Dates'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (me != null) ...[
                          const Text('MY PROGRESS', style: labelCapsStyle),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: (me.currentChapter ?? 0) > 0 ? () => _updateProgress(chapter: (me.currentChapter ?? 0) - 1) : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('Chapter ${me.currentChapter ?? 0}${book.totalChapters != null ? " / ${book.totalChapters}" : ""}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              IconButton(
                                onPressed: () => _updateProgress(chapter: (me.currentChapter ?? 0) + 1),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                          SwitchTile(
                            label: "I've finished this book",
                            value: me.finished ?? false,
                            onChanged: (v) => _updateProgress(finished: v),
                          ),
                        ],
                        const SizedBox(height: 14),
                        const Text('CLUB PROGRESS', style: labelCapsStyle),
                        const SizedBox(height: 8),
                        ...club.activeMembers.map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      UserAvatar(avatarUrl: m.avatarUrl, initials: m.initials, size: 26),
                                      const SizedBox(width: 8),
                                      Text(m.name, style: const TextStyle(fontSize: 12.5)),
                                    ],
                                  ),
                                  Text(
                                    m.finished == true ? 'Finished' : 'Chapter ${m.currentChapter ?? 0}',
                                    style: TextStyle(fontSize: 11.5, color: m.finished == true ? AppColors.green : AppColors.inkSoft, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _ActionCard(icon: Icons.edit_note_rounded, label: 'Notes', onTap: book == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubNotesScreen(clubId: widget.clubId, book: book))))),
                const SizedBox(width: 10),
                Expanded(child: _ActionCard(icon: Icons.reviews_outlined, label: 'Reviews', onTap: book == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubReviewsScreen(clubId: widget.clubId, book: book))))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _ActionCard(icon: Icons.grid_on_rounded, label: 'Bingo', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubBingoScreen(clubId: widget.clubId))))),
                const SizedBox(width: 10),
                Expanded(child: _ActionCard(icon: Icons.history_rounded, label: 'History', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubHistoryScreen(clubId: widget.clubId))))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.paperSoft : AppColors.paperSoft.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: enabled ? AppColors.green : AppColors.lineStrong),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: enabled ? AppColors.ink : AppColors.lineStrong)),
          ],
        ),
      ),
    );
  }
}
