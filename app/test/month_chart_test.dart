import 'package:bookmarked/models/dashboard.dart';
import 'package:bookmarked/screens/home/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Dashboard _dashboard(List<int> monthCounts) => Dashboard(
      year: 2026,
      availableYears: const [2026],
      totalRead: monthCounts.fold(0, (a, b) => a + b),
      avgRating: 0,
      pagesRead: 0,
      byGenre: const [],
      byRating: const [],
      byMonth: [for (var m = 1; m <= 12; m++) MonthCount(m, monthCounts[m - 1])],
    );

void main() {
  testWidgets('every month draws a bar with a real width, including months with books', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // One book in September, like the report: the "1" label showed with no bar.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: MonthChart(dash: _dashboard([0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0])),
        ),
      ),
    ));

    final bars = find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox));
    expect(bars, findsNWidgets(12));
    for (final bar in bars.evaluate()) {
      expect(tester.getSize(find.byWidget(bar.widget)).width, greaterThan(0));
    }
  });
}
