import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../providers/books_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme.dart';
import '../../widgets/genre_chip.dart';

class EditBookScreen extends ConsumerStatefulWidget {
  final Book book;
  const EditBookScreen({super.key, required this.book});

  @override
  ConsumerState<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends ConsumerState<EditBookScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _seriesCtrl;
  late final TextEditingController _bookNoCtrl;
  late final TextEditingController _pagesCtrl;
  late final TextEditingController _publishedCtrl;
  String? _genre;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    _titleCtrl = TextEditingController(text: b.title);
    _authorCtrl = TextEditingController(text: b.author);
    _seriesCtrl = TextEditingController(text: b.series ?? '');
    _bookNoCtrl = TextEditingController(text: b.bookNo?.toString() ?? '');
    _pagesCtrl = TextEditingController(text: b.pages?.toString() ?? '');
    _publishedCtrl = TextEditingController(text: b.published ?? '');
    _genre = b.genre;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _seriesCtrl.dispose();
    _bookNoCtrl.dispose();
    _pagesCtrl.dispose();
    _publishedCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the book a title first')));
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'title': _titleCtrl.text.trim(),
      'author': _authorCtrl.text.trim().isEmpty ? 'Unknown author' : _authorCtrl.text.trim(),
      'series': _seriesCtrl.text.trim().isEmpty ? null : _seriesCtrl.text.trim(),
      'bookNo': int.tryParse(_bookNoCtrl.text.trim()),
      'genre': _genre,
      'pages': int.tryParse(_pagesCtrl.text.trim()),
      'published': _publishedCtrl.text.trim().isEmpty ? null : _publishedCtrl.text.trim(),
    };

    final book = await ref.read(booksProvider.notifier).update(widget.book.id, payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (book != null) {
      ref.invalidate(dashboardProvider);
      Navigator.of(context).pop(true);
    } else {
      final error = ref.read(booksProvider).error ?? 'Could not save these changes';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Edit Book', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TITLE', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Book title')),
            const SizedBox(height: 16),
            const Text('AUTHOR', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(controller: _authorCtrl, decoration: const InputDecoration(hintText: 'Author name')),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SERIES (OPTIONAL)', style: labelCapsStyle),
                      const SizedBox(height: 6),
                      TextField(controller: _seriesCtrl, decoration: const InputDecoration(hintText: 'e.g. Dark Olympus')),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BOOK #', style: labelCapsStyle),
                      const SizedBox(height: 6),
                      TextField(controller: _bookNoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '1')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('GENRE', style: labelCapsStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: genreOptions.map((g) => GenreChip(label: g, active: _genre == g, onTap: () => setState(() => _genre = _genre == g ? null : g))).toList(),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PAGES', style: labelCapsStyle),
                      const SizedBox(height: 6),
                      TextField(controller: _pagesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '320')),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PUBLISHED', style: labelCapsStyle),
                      const SizedBox(height: 6),
                      TextField(controller: _publishedCtrl, decoration: const InputDecoration(hintText: 'e.g. 2019')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
