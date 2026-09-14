import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookmarked/main.dart';

void main() {
  testWidgets('App boots to the welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BookmarkedApp()));
    await tester.pump();

    expect(find.text('Bookmarked'), findsWidgets);
  });
}
