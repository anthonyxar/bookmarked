import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import 'auth_provider.dart';

final bookDetailProvider = FutureProvider.family<Book, String>((ref, bookId) async {
  final json = await ref.watch(apiClientProvider).get('/books/$bookId');
  return Book.fromJson(json as Map<String, dynamic>);
});
