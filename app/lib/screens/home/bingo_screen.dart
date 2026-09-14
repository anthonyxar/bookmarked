import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bingo_provider.dart';
import '../../theme.dart';
import '../../widgets/bingo_cell_widget.dart';

class BingoScreen extends ConsumerStatefulWidget {
  const BingoScreen({super.key});

  @override
  ConsumerState<BingoScreen> createState() => _BingoScreenState();
}

class _BingoScreenState extends ConsumerState<BingoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(bingoProvider.notifier).load());
  }

  Future<void> _renameSquare(String id, String currentLabel) async {
    final controller = TextEditingController(text: currentLabel);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paperSoft,
        title: const Text('Edit square'),
        content: TextField(controller: controller, autofocus: true, maxLength: 60),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(bingoProvider.notifier).renameSquare(id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bingoProvider);
    final card = state.card;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: card == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.green))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${card.year} Reading Bingo', style: AppTheme.serif.copyWith(fontSize: 20)),
                        GestureDetector(
                          onTap: () => ref.read(bingoProvider.notifier).toggleEditMode(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: state.editMode ? AppColors.green : AppColors.paperSoft,
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.edit_outlined, size: 16, color: state.editMode ? Colors.white : AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${card.completedCount} / ${card.squares.length} squares complete', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: card.squares.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 6, crossAxisSpacing: 6),
                        itemBuilder: (context, i) {
                          final square = card.squares[i];
                          return BingoCellWidget(
                            label: square.label,
                            completed: square.completed,
                            locked: square.locked,
                            editMode: state.editMode,
                            onTap: state.editMode
                                ? () => _renameSquare(square.id, square.label)
                                : () => ref.read(bingoProvider.notifier).toggleSquare(square.id, square.completed),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => ref.read(bingoProvider.notifier).reset(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border.all(color: AppColors.lineStrong), borderRadius: BorderRadius.circular(10)),
                        child: const Text('Reset Card', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
