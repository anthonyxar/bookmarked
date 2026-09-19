import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/books_provider.dart';
import '../../theme.dart';
import '../../widgets/club_book_cover.dart';

/// Pick up to five favourite books from the shelf and drag them into rank
/// order. Saved to the profile as [TopBook] snapshots.
class EditTopBooksScreen extends ConsumerStatefulWidget {
  const EditTopBooksScreen({super.key});

  @override
  ConsumerState<EditTopBooksScreen> createState() => _EditTopBooksScreenState();
}

class _EditTopBooksScreenState extends ConsumerState<EditTopBooksScreen> {
  late final List<TopBook> _picks = List.of(ref.read(authProvider).user?.topBooks ?? const <TopBook>[]);
  bool _saving = false;

  Future<void> _addBook() async {
    final taken = {for (final p in _picks) p.bookId};
    // Read books first — favourites are usually ones you've finished.
    final available = (ref.read(userBooksProvider).value ?? const <Book>[]).where((b) => !taken.contains(b.id)).toList()
      ..sort((a, b) {
        if (a.read != b.read) return a.read ? -1 : 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    final picked = await showModalBottomSheet<Book>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperSoft,
      builder: (_) => _BookPickerSheet(books: available),
    );
    if (picked == null || !mounted) return;
    setState(() => _picks.add(TopBook(
          bookId: picked.id,
          title: picked.title,
          author: picked.author,
          coverColor: picked.coverColor,
          coverUrl: picked.coverUrl,
        )));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).setTopBooks(_picks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your top 5. Check your connection and try again.')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final full = _picks.length >= AppUser.maxTopBooks;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Top 5 books', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose up to five favourites from your shelf and drag them into order — number one first.',
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) => setState(() {
                _picks.insert(newIndex, _picks.removeAt(oldIndex));
              }),
              children: [
                for (var i = 0; i < _picks.length; i++)
                  _PickTile(
                    key: ValueKey(_picks[i].bookId),
                    index: i,
                    book: _picks[i],
                    onRemove: () => setState(() => _picks.removeAt(i)),
                  ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: full ? null : _addBook,
              icon: const Icon(Icons.add, size: 18),
              label: Text(full ? 'You have five' : 'Add a book'),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final int index;
  final TopBook book;
  final VoidCallback onRemove;
  const _PickTile({super.key, required this.index, required this.book, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
            child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          ClubBookCover(title: book.title, coverColor: book.coverColor, coverUrl: book.coverUrl, width: 32, height: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18, color: AppColors.inkSoft),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 10, 8),
              child: Icon(Icons.drag_handle, size: 22, color: AppColors.lineStrong),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookPickerSheet extends StatefulWidget {
  final List<Book> books;
  const _BookPickerSheet({required this.books});

  @override
  State<_BookPickerSheet> createState() => _BookPickerSheetState();
}

class _BookPickerSheetState extends State<_BookPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.books
        : widget.books.where((b) => b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'Search your shelf', prefixIcon: Icon(Icons.search, size: 20)),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.books.isEmpty ? 'Add some books to your shelf first.' : 'No books match that search.',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line),
                      itemBuilder: (context, i) {
                        final b = shown[i];
                        return ListTile(
                          onTap: () => Navigator.pop(context, b),
                          contentPadding: EdgeInsets.zero,
                          leading: ClubBookCover(title: b.title, coverColor: b.coverColor, coverUrl: b.coverUrl, width: 32, height: 46),
                          title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(b.read ? '${b.author} · Read' : b.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
