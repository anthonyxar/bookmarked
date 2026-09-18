import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/club.dart';
import '../../models/club_bingo.dart';
import '../../providers/club_detail_provider.dart';
import '../../providers/clubs_provider.dart';
import '../../services/api_client.dart';
import '../../theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_state.dart';
import '../../widgets/user_avatar.dart';

class ClubManageScreen extends ConsumerStatefulWidget {
  final String clubId;
  const ClubManageScreen({super.key, required this.clubId});

  @override
  ConsumerState<ClubManageScreen> createState() => _ClubManageScreenState();
}

class _ClubManageScreenState extends ConsumerState<ClubManageScreen> {
  List<TextEditingController> _labelControllers = [];
  bool _savingTemplate = false;

  void _syncControllers(ClubBingo bingo) {
    if (_labelControllers.length == bingo.squares.length) return;
    for (final c in _labelControllers) {
      c.dispose();
    }
    _labelControllers = bingo.squares.map((s) => TextEditingController(text: s.label)).toList();
  }

  Future<void> _reload() async {
    await Future.wait([
      ref.refresh(clubDetailProvider(widget.clubId).future),
      ref.refresh(clubBingoProvider(widget.clubId).future),
    ]);
  }

  Future<void> _changeRole(String userId, String name, String newRole) async {
    final confirmed = await confirmDialog(
      context,
      title: newRole == 'admin' ? 'Make $name an admin?' : 'Remove $name as admin?',
      message: newRole == 'admin'
          ? '$name will be able to invite/remove members and edit the club bingo card.'
          : '$name will go back to being a regular member.',
      confirmLabel: 'Confirm',
      danger: false,
    );
    if (!confirmed) return;
    final ok = await ref.read(clubsProvider.notifier).updateMemberRole(widget.clubId, userId, newRole);
    if (ok) {
      ref.invalidate(clubDetailProvider(widget.clubId));
    } else if (mounted) {
      final error = ref.read(clubsProvider).error ?? 'Could not update that member';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _removeMember(String userId, String name) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Remove $name?',
      message: '$name will lose access to this club and its history unless re-invited.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    final ok = await ref.read(clubsProvider.notifier).removeMember(widget.clubId, userId);
    if (ok) {
      ref.invalidate(clubDetailProvider(widget.clubId));
    } else if (mounted) {
      final error = ref.read(clubsProvider).error ?? 'Could not remove that member';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _transferOwnership(String userId, String name) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Make $name the owner?',
      message: "You'll become an admin. Only $name will then be able to delete the club or transfer ownership again.",
      confirmLabel: 'Transfer',
    );
    if (!confirmed) return;
    final ok = await ref.read(clubsProvider.notifier).transferOwnership(widget.clubId, userId);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(clubDetailProvider(widget.clubId));
    } else {
      final error = ref.read(clubsProvider).error ?? 'Could not transfer ownership';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _saveTemplate() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Update bingo card?',
      message: 'This replaces the club bingo card for everyone and resets all progress. This can\'t be undone.',
      confirmLabel: 'Update',
    );
    if (!confirmed) return;
    final labels = _labelControllers.map((c) => c.text.trim().isEmpty ? 'FREE SPACE' : c.text.trim()).toList();
    setState(() => _savingTemplate = true);
    final ok = await ref.read(clubsProvider.notifier).setBingoTemplate(widget.clubId, labels);
    if (mounted) {
      if (ok) {
        ref.invalidate(clubBingoProvider(widget.clubId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bingo card updated for everyone')));
      } else {
        final error = ref.read(clubsProvider).error ?? 'Could not update the bingo card';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      setState(() => _savingTemplate = false);
    }
  }

  @override
  void dispose() {
    for (final c in _labelControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clubAsync = ref.watch(clubDetailProvider(widget.clubId));
    final bingoAsync = ref.watch(clubBingoProvider(widget.clubId));
    bingoAsync.whenData(_syncControllers);

    Widget body;
    if (clubAsync.isLoading || bingoAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.green));
    } else if (clubAsync.hasError) {
      body = ErrorState(
        message: clubAsync.error is ApiException ? (clubAsync.error as ApiException).message : '${clubAsync.error}',
        onRetry: _reload,
      );
    } else if (bingoAsync.hasError) {
      body = ErrorState(
        message: bingoAsync.error is ApiException ? (bingoAsync.error as ApiException).message : '${bingoAsync.error}',
        onRetry: _reload,
      );
    } else {
      body = _buildBody(clubAsync.value!);
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Manage Club', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SafeArea(child: body),
    );
  }

  Widget _buildBody(Club club) {
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: _reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MEMBERS', style: labelCapsStyle),
            const SizedBox(height: 8),
            ...club.members.where((m) => m.status == 'active' || m.status == 'invited').map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      UserAvatar(avatarUrl: m.avatarUrl, initials: m.initials, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            Text(m.status == 'invited' ? 'Invited · ${m.role}' : m.role, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                      if (m.role != 'owner') ...[
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.inkSoft),
                          onSelected: (value) {
                            if (value == 'toggleAdmin') _changeRole(m.userId, m.name, m.role == 'admin' ? 'member' : 'admin');
                            if (value == 'remove') _removeMember(m.userId, m.name);
                            if (value == 'transfer') _transferOwnership(m.userId, m.name);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'toggleAdmin', child: Text(m.role == 'admin' ? 'Make Member' : 'Make Admin')),
                            if (m.status == 'active') const PopupMenuItem(value: 'transfer', child: Text('Make Owner')),
                            const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: AppColors.terra))),
                          ],
                        ),
                      ],
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            const Text('BINGO CARD LABELS', style: labelCapsStyle),
            const SizedBox(height: 4),
            const Text(
              'Editing this replaces the club bingo card for everyone and resets progress. Square 13 is always the free space.',
              style: TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_labelControllers.length, (i) {
                return SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _labelControllers[i],
                    enabled: i != 12,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: InputDecoration(labelText: 'Square ${i + 1}', labelStyle: const TextStyle(fontSize: 10)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingTemplate ? null : _saveTemplate,
                child: _savingTemplate
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Bingo Card'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
