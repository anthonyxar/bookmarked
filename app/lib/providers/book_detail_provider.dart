import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import 'auth_provider.dart';

final bookDetailProvider = StreamProvider.autoDispose.family<Book, String>((ref, bookId) {
  final uid = ref.watch(authProvider.select((s) => s.user?.id));
  if (uid == null) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('books')
      .doc(bookId)
      .snapshots()
      .map(Book.fromFirestore);
});
