import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/auth/auth_gate.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: BookmarkedApp()));
}

class BookmarkedApp extends StatelessWidget {
  const BookmarkedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bookmarked',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
