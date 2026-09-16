import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book_search_result.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme.dart';
import '../../widgets/date_field.dart';

class ClubBookPickerScreen extends ConsumerStatefulWidget {
  final String clubId;
  const ClubBookPickerScreen({super.key, required this.clubId});

  @override
  ConsumerState<ClubBookPickerScreen> createState() => _ClubBookPickerScreenState();
}

class _ClubBookPickerScreenState extends ConsumerState<ClubBookPickerScreen> {
  final _searchCtrl = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _chaptersController = TextEditingController();
  bool _saving = false;

  Timer? _debounce;
  bool _searching = false;
  String? _searchError;
  List<BookSearchResult> _results = [];
  String? _selectedCoverUrl;
  DateTime? _startDate;
  DateTime? _endDate;

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
      final json = await ref.read(apiClientProvider).get('/books/search', query: {'q': query});
      final results = (json as List).map((r) => BookSearchResult.fromJson(r as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _searchError = results.isEmpty ? 'No matches found — you can still enter it manually below.' : null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = [];
        _searchError = e.message;
      });
    }
  }

  void _selectResult(BookSearchResult result) {
    setState(() {
      _titleController.text = result.title;
      _authorController.text = result.author;
      _selectedCoverUrl = result.coverUrl;
      _results = [];
      _searchError = null;
      _searchCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    if (title.isEmpty || author.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post('/clubs/${widget.clubId}/book', body: {
        'title': title,
        'author': author,
        'total_chapters': _chaptersController.text.trim().isEmpty ? null : int.tryParse(_chaptersController.text.trim()),
        if (_selectedCoverUrl != null) 'cover_url': _selectedCoverUrl,
        if (_startDate != null) 'start_date': dateFieldFmt.format(_startDate!),
        if (_endDate != null) 'end_date': dateFieldFmt.format(_endDate!),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _chaptersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Pick a Book', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This becomes the club's current read. Everyone's chapter progress resets for this pick.",
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.5),
              ),
              const SizedBox(height: 20),
              const Text('FIND A BOOK', style: labelCapsStyle),
              const SizedBox(height: 6),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
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
              const SizedBox(height: 8),
              TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'Book title')),
              const SizedBox(height: 20),
              const Text('AUTHOR', style: labelCapsStyle),
              const SizedBox(height: 8),
              TextField(controller: _authorController, decoration: const InputDecoration(hintText: 'Author name')),
              const SizedBox(height: 20),
              const Text('TOTAL CHAPTERS (OPTIONAL)', style: labelCapsStyle),
              const SizedBox(height: 8),
              TextField(controller: _chaptersController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'e.g. 32')),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: AppDateField(label: 'Started', date: _startDate, onTap: () => _pickDate(isStart: true))),
                  const SizedBox(width: 10),
                  Expanded(child: AppDateField(label: 'Finished', date: _endDate, onTap: () => _pickDate(isStart: false))),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Set Book'),
                ),
              ),
            ],
          ),
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
