import 'package:flutter/material.dart';

import '../theme.dart';

class ChipListInput extends StatefulWidget {
  final List<String> items;
  final String hint;
  final ValueChanged<List<String>> onChanged;

  const ChipListInput({super.key, required this.items, required this.hint, required this.onChanged});

  @override
  State<ChipListInput> createState() => _ChipListInputState();
}

class _ChipListInputState extends State<ChipListInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final value = _ctrl.text.trim();
    if (value.isEmpty) return;
    widget.onChanged([...widget.items, value]);
    _ctrl.clear();
  }

  void _remove(int index) {
    final next = [...widget.items]..removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(widget.items.length, (i) {
                return Chip(
                  label: Text(widget.items[i], style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.creamDark,
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => _remove(i),
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(hintText: widget.hint),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _add,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.green),
                child: const Icon(Icons.add, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
