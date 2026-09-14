import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/books_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme.dart';
import '../../widgets/date_field.dart';
import '../../widgets/genre_chip.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/switch_tile.dart';
import '../../widgets/yes_no_toggle.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _seriesCtrl.dispose();
    super.dispose();
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
      if (_read && _startDate != null) 'start_date': dateFieldFmt.format(_startDate!),
      if (_read && _endDate != null) 'end_date': dateFieldFmt.format(_endDate!),
      if (_read) 'rating_cover': _ratings['cover'],
      if (_read) 'rating_writing': _ratings['writing'],
      if (_read) 'rating_plot': _ratings['plot'],
      if (_read) 'rating_characters': _ratings['characters'],
      if (_read) 'enjoyed': _enjoyed,
      if (_read) 'read_again': _readAgain,
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
}
