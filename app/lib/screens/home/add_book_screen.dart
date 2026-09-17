import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book_search_result.dart';
import '../../providers/books_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/book_search_service.dart';
import '../../theme.dart';
import '../../widgets/date_field.dart';
import '../../widgets/genre_chip.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/switch_tile.dart';
import '../../widgets/yes_no_toggle.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialAuthor;
  final String? initialCoverUrl;
  const AddBookScreen({super.key, this.initialTitle, this.initialAuthor, this.initialCoverUrl});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _searchCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _seriesCtrl = TextEditingController();
  String _genre = 'Romance';
  bool _purchased = false;
  bool _read = false;
  DateTime? _startDate;
  DateTime? _endDate;
  final Map<String, int> _ratings = {'cover': 0, 'writing': 0, 'plot': 0, 'characters': 0};
  bool _enjoyed = false;
  bool _readAgain = false;
  bool _saving = false;

  Timer? _debounce;
  bool _searching = false;
  String? _searchError;
  List<BookSearchResult> _results = [];
  String? _selectedCoverUrl;
  int? _selectedPages;
  String? _selectedPublished;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialTitle ?? '';
    _authorCtrl.text = widget.initialAuthor ?? '';
    _selectedCoverUrl = widget.initialCoverUrl;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _seriesCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _runSearch(value.trim()));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await searchBooks(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _searchError = results.isEmpty ? 'No matches found — you can still enter it manually below.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = [];
        _searchError = 'Search failed — you can still enter it manually below.';
      });
    }
  }

  void _selectResult(BookSearchResult result) {
    setState(() {
      _titleCtrl.text = result.title;
      _authorCtrl.text = result.author;
      if (result.genre != null && genreOptions.contains(result.genre)) {
        _genre = result.genre!;
      }
      _selectedCoverUrl = result.coverUrl;
      _selectedPages = result.pages;
      _selectedPublished = result.published;
      _results = [];
      _searchError = null;
      _searchCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
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
      'genre': _genre,
      'purchased': _purchased,
      'read': _read,
      if (_selectedCoverUrl != null) 'coverUrl': _selectedCoverUrl,
      if (_selectedPages != null) 'pages': _selectedPages,
      if (_selectedPublished != null) 'published': _selectedPublished,
      if (_read && _startDate != null) 'startDate': _startDate,
      if (_read && _endDate != null) 'endDate': _endDate,
      if (_read) 'ratingCover': _ratings['cover'],
      if (_read) 'ratingWriting': _ratings['writing'],
      if (_read) 'ratingPlot': _ratings['plot'],
      if (_read) 'ratingCharacters': _ratings['characters'],
      if (_read) 'enjoyed': _enjoyed,
      if (_read) 'readAgain': _readAgain,
    };

    final book = await ref.read(booksProvider.notifier).create(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (book != null) {
      ref.invalidate(dashboardProvider);
      Navigator.of(context).pop();
    } else {
      final error = ref.read(booksProvider).error ?? 'Could not save this book';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Add to Wishlist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FIND A BOOK', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by title or author',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green)),
                      )
                    : const Icon(Icons.search, size: 20, color: AppColors.inkSoft),
              ),
            ),
            if (_searchError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_searchError!, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
              ),
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _results.length,
                  separatorBuilder: (context, i) => const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    return ListTile(
                      onTap: () => _selectResult(r),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      leading: SizedBox(
                        width: 36,
                        height: 52,
                        child: r.coverUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(r.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _coverFallback()),
                              )
                            : _coverFallback(),
                      ),
                      title: Text(r.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(r.author, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
              ),
            const SizedBox(height: 22),
            if (_selectedCoverUrl != null) ...[
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_selectedCoverUrl!, width: 84, height: 122, fit: BoxFit.cover, errorBuilder: (_, _, _) => _coverFallback(width: 84, height: 122)),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCoverUrl = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            const Text('TITLE', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Book title')),
            const SizedBox(height: 16),
            const Text('AUTHOR', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(controller: _authorCtrl, decoration: const InputDecoration(hintText: 'Author name')),
            const SizedBox(height: 16),
            const Text('SERIES (OPTIONAL)', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(controller: _seriesCtrl, decoration: const InputDecoration(hintText: 'e.g. Dark Olympus')),
            const SizedBox(height: 18),
            const Text('GENRE', style: labelCapsStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: genreOptions.map((g) => GenreChip(label: g, active: _genre == g, onTap: () => setState(() => _genre = g))).toList(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: SwitchTile(label: 'Purchased', value: _purchased, onChanged: (v) => setState(() => _purchased = v))),
                const SizedBox(width: 10),
                Expanded(child: SwitchTile(label: 'Read', value: _read, onChanged: (v) => setState(() => _read = v))),
              ],
            ),
            if (_read) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: AppDateField(label: 'Started', date: _startDate, onTap: () => _pickDate(isStart: true))),
                  const SizedBox(width: 10),
                  Expanded(child: AppDateField(label: 'Finished', date: _endDate, onTap: () => _pickDate(isStart: false))),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RATE IT', style: labelCapsStyle),
                    const SizedBox(height: 12),
                    for (final entry in {'cover': 'Cover Design', 'writing': 'Writing Style', 'plot': 'Story & Plot', 'characters': 'Characters'}.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            StarRating(
                              rating: _ratings[entry.key]!,
                              size: 20,
                              editable: true,
                              onRate: (v) => setState(() => _ratings[entry.key] = v),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: YesNoToggle(label: 'Enjoyed it', value: _enjoyed, onChanged: (v) => setState(() => _enjoyed = v))),
                  const SizedBox(width: 10),
                  Expanded(child: YesNoToggle(label: 'Would reread', value: _readAgain, onChanged: (v) => setState(() => _readAgain = v))),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "You can add your full review — thoughts, favourite characters, quotes — from the book's detail page once it's saved.",
                style: TextStyle(fontSize: 11, color: AppColors.inkSoft, fontStyle: FontStyle.italic, height: 1.4),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save to Wishlist'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback({double width = 36, double height = 52}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.creamDark, borderRadius: BorderRadius.circular(4)),
      child: const Icon(Icons.menu_book_outlined, size: 16, color: AppColors.inkSoft),
    );
  }
}
