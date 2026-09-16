import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/club.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme.dart';
import '../../widgets/club_book_cover.dart';
import 'club_notes_screen.dart';
import 'club_reviews_screen.dart';

final _dateFmt = DateFormat('MMM yyyy');
final _fullDateFmt = DateFormat('MMM d, yyyy');

String _dateLabel(ClubBook book) {
  if (book.startDate != null && book.endDate != null) {
    return '${_fullDateFmt.format(book.startDate!)} – ${_fullDateFmt.format(book.endDate!)}';
  }
  if (book.startDate != null) {
    return 'Started ${_fullDateFmt.format(book.startDate!)}';
  }
  if (book.endDate != null) {
    return 'Finished ${_fullDateFmt.format(book.endDate!)}';
  }
  return 'Picked ${_dateFmt.format(book.pickedAt)}';
}

class ClubHistoryScreen extends ConsumerStatefulWidget {
  final String clubId;
  const ClubHistoryScreen({super.key, required this.clubId});

  @override
  ConsumerState<ClubHistoryScreen> createState() => _ClubHistoryScreenState();
}

class _ClubHistoryScreenState extends ConsumerState<ClubHistoryScreen> {
  List<ClubBook> _books = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await ref.read(apiClientProvider).get('/clubs/${widget.clubId}/books', query: {'limit': '200'});
      final items = (json as Map<String, dynamic>)['items'] as List;
      setState(() {
        _books = items.map((b) => ClubBook.fromJson(b as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Book History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.green))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.terra)))
                : _books.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text("This club hasn't picked any books yet.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.green,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                          itemCount: _books.length,
                          itemBuilder: (context, i) {
                            final book = _books[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClubBookCover(title: book.title, coverColor: book.coverColor, coverUrl: book.coverUrl),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ),
                                            if (book.isCurrent)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(999)),
                                                child: const Text('CURRENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.green)),
                                              ),
                                          ],
                                        ),
                                        Text(book.author, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text(_dateLabel(book), style: const TextStyle(fontSize: 10.5, color: AppColors.lineStrong)),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _LinkButton(
                                              label: 'Notes',
                                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubNotesScreen(clubId: widget.clubId, book: book))),
                                            ),
                                            const SizedBox(width: 16),
                                            _LinkButton(
                                              label: 'Reviews',
                                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubReviewsScreen(clubId: widget.clubId, book: book))),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.green)),
    );
  }
}
