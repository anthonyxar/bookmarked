import 'package:bookmarked/models/user.dart';
import 'package:bookmarked/widgets/top_books_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TopBook _book(String title) => TopBook(bookId: title, title: title, author: 'Someone', coverColor: '#4A6B7A');

Widget _host(List<TopBook> books) => MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(18), child: TopBooksRow(books: books)),
      ),
    );

void main() {
  testWidgets('always shows five slots: picks first, then numbered empty ones', (tester) async {
    await tester.pumpWidget(_host([_book('Dune'), _book('Emma')]));

    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Emma'), findsOneWidget);
    // Ranks 1-2 are badges on the covers, ranks 3-5 are the empty slots.
    for (final rank in ['1', '2', '3', '4', '5']) {
      expect(find.text(rank), findsOneWidget, reason: 'rank $rank');
    }
  });

  testWidgets('an empty profile shows five empty slots', (tester) async {
    await tester.pumpWidget(_host(const []));

    for (final rank in ['1', '2', '3', '4', '5']) {
      expect(find.text(rank), findsOneWidget);
    }
  });

  for (final width in [320.0, 360.0, 411.0]) {
    testWidgets('five long-titled books do not overflow at ${width}dp', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host([for (var i = 1; i <= 5; i++) _book('A Very Long Book Title Number $i')]));

      expect(tester.takeException(), isNull);
    });
  }

  test('TopBook survives a round trip through its Firestore map', () {
    const book = TopBook(bookId: 'b1', title: 'Dune', author: 'Frank Herbert', coverColor: '#123456', coverUrl: 'https://x/y.jpg');
    final again = TopBook.fromMap(book.toMap());
    expect(again.bookId, 'b1');
    expect(again.title, 'Dune');
    expect(again.author, 'Frank Herbert');
    expect(again.coverColor, '#123456');
    expect(again.coverUrl, 'https://x/y.jpg');
  });
}
