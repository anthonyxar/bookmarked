import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/clubs_provider.dart';
import '../../theme.dart';

class CreateClubScreen extends ConsumerStatefulWidget {
  const CreateClubScreen({super.key});

  @override
  ConsumerState<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends ConsumerState<CreateClubScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final club = await ref.read(clubsProvider.notifier).create(name, _descController.text.trim().isEmpty ? null : _descController.text.trim());
    setState(() => _saving = false);

    if (club != null && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      final error = ref.read(clubsProvider).error;
      if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('New Book Club', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CLUB NAME', style: labelCapsStyle),
              const SizedBox(height: 8),
              TextField(controller: _nameController, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Fireside Readers')),
              const SizedBox(height: 20),
              const Text('DESCRIPTION (OPTIONAL)', style: labelCapsStyle),
              const SizedBox(height: 8),
              TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(hintText: 'What is this club about?')),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Club'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
