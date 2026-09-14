import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_client.dart';
import '../../theme.dart';
import '../../widgets/chip_list_input.dart';
import '../../widgets/date_field.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/yes_no_toggle.dart';

const _categoryLabels = {
  'cover': 'Cover Design',
  'writing': 'Writing Style',
  'plot': 'Story & Plot',
  'characters': 'Characters',
};

class EditReviewScreen extends ConsumerStatefulWidget {
  final Book book;
  const EditReviewScreen({super.key, required this.book});

  @override
  ConsumerState<EditReviewScreen> createState() => _EditReviewScreenState();
}

class _EditReviewScreenState extends ConsumerState<EditReviewScreen> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late final Map<String, int> _ratings;
  late bool _enjoyed;
  late bool _readAgain;
  late final TextEditingController _likedMostCtrl;
  late final TextEditingController _likedLeastCtrl;
  late final TextEditingController _feelCtrl;
  late final TextEditingController _tropeCtrl;
  late final TextEditingController _finalReviewCtrl;
  late final TextEditingController _scenesCtrl;
  late final TextEditingController _quotesCtrl;
  late List<String> _favoriteCharacters;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    _startDate = b.startDate;
    _endDate = b.endDate;
    _ratings = {
      'cover': b.ratingCover ?? 0,
      'writing': b.ratingWriting ?? 0,
      'plot': b.ratingPlot ?? 0,
      'characters': b.ratingCharacters ?? 0,
    };
    _enjoyed = b.enjoyed ?? false;
    _readAgain = b.readAgain ?? false;
    _likedMostCtrl = TextEditingController(text: b.likedMost ?? '');
    _likedLeastCtrl = TextEditingController(text: b.likedLeast ?? '');
    _feelCtrl = TextEditingController(text: b.feel ?? '');
    _tropeCtrl = TextEditingController(text: b.trope ?? '');
    _finalReviewCtrl = TextEditingController(text: b.finalReview ?? '');
    _scenesCtrl = TextEditingController(text: b.notableScenes.join('\n'));
    _quotesCtrl = TextEditingController(text: b.quotes.join('\n'));
    _favoriteCharacters = List.of(b.favoriteCharacters);
  }

  @override
  void dispose() {
    _likedMostCtrl.dispose();
    _likedLeastCtrl.dispose();
    _feelCtrl.dispose();
    _tropeCtrl.dispose();
    _finalReviewCtrl.dispose();
    _scenesCtrl.dispose();
    _quotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  List<String> _linesOf(String text) => text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  Future<void> _save() async {
    setState(() => _saving = true);
    final payload = {
      'read': true,
      if (_startDate != null) 'start_date': dateFieldFmt.format(_startDate!),
      if (_endDate != null) 'end_date': dateFieldFmt.format(_endDate!),
      'rating_cover': _ratings['cover'],
      'rating_writing': _ratings['writing'],
      'rating_plot': _ratings['plot'],
      'rating_characters': _ratings['characters'],
      'enjoyed': _enjoyed,
      'read_again': _readAgain,
      'liked_most': _likedMostCtrl.text.trim(),
      'liked_least': _likedLeastCtrl.text.trim(),
      'feel': _feelCtrl.text.trim(),
      'trope': _tropeCtrl.text.trim(),
      'final_review': _finalReviewCtrl.text.trim(),
      'favorite_characters': _favoriteCharacters,
      'notable_scenes': _linesOf(_scenesCtrl.text),
      'quotes': _linesOf(_quotesCtrl.text),
    };

    try {
      await ref.read(apiClientProvider).patch('/books/${widget.book.id}', body: payload);
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text('Review · ${widget.book.title}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  for (final entry in _categoryLabels.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          StarRating(
                            rating: _ratings[entry.key]!,
                            size: 22,
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
            const SizedBox(height: 22),
            Text('Thoughts', style: AppTheme.serif.copyWith(fontSize: 16)),
            const Divider(color: AppColors.line, height: 18),
            const Text('WHAT DID YOU LIKE THE MOST?', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(controller: _likedMostCtrl, maxLines: 3, decoration: const InputDecoration(hintText: '...')),
            const SizedBox(height: 16),
            const Text('WHAT DID YOU LIKE THE LEAST?', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(controller: _likedLeastCtrl, maxLines: 3, decoration: const InputDecoration(hintText: '...')),
            const SizedBox(height: 16),
            const Text('HOW DID THIS BOOK MAKE YOU FEEL?', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(controller: _feelCtrl, maxLines: 2, decoration: const InputDecoration(hintText: '...')),
            const SizedBox(height: 22),
            const Text('TROPE', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(controller: _tropeCtrl, decoration: const InputDecoration(hintText: 'e.g. Enemies to Lovers')),
            const SizedBox(height: 22),
            const Text('FAVOURITE CHARACTERS', style: labelCapsStyle),
            const SizedBox(height: 8),
            ChipListInput(
              items: _favoriteCharacters,
              hint: 'Add a character',
              onChanged: (v) => setState(() => _favoriteCharacters = v),
            ),
            const SizedBox(height: 22),
            const Text('NOTABLE SCENES', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(
              controller: _scenesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'One per line'),
            ),
            const SizedBox(height: 22),
            Text('Final Review', style: AppTheme.serif.copyWith(fontSize: 16)),
            const Divider(color: AppColors.line, height: 18),
            TextField(controller: _finalReviewCtrl, maxLines: 6, decoration: const InputDecoration(hintText: 'Your overall thoughts on this one...')),
            const SizedBox(height: 22),
            const Text('FAVOURITE QUOTES', style: labelCapsStyle),
            const SizedBox(height: 6),
            TextField(
              controller: _quotesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'One per line'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
  }
}
