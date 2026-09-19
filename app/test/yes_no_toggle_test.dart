import 'package:bookmarked/widgets/yes_no_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The review screens (add_book_screen.dart, edit_review_screen.dart) put two
// toggles side by side under 18px page padding, so each gets a bit under half
// the screen — on real phones that overflowed ("RIGHT OVERFLOWED BY 14 PIXELS").
Widget _row() => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
          child: Row(
            children: [
              Expanded(child: YesNoToggle(label: 'Enjoyed it', value: true, onChanged: (_) {})),
              const SizedBox(width: 10),
              Expanded(child: YesNoToggle(label: 'Would reread', value: false, onChanged: (_) {})),
            ],
          ),
        ),
      ),
    );

// Flutter tests render text in the Ahem test font, whose glyphs are far wider
// than the app's real font, so these widths are deliberately the realistic
// upper half of phones: narrower ones would fail only because of Ahem.
void main() {
  for (final width in [360.0, 411.0]) {
    testWidgets('side-by-side toggles do not overflow at ${width}dp', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_row());

      expect(tester.takeException(), isNull);
    });
  }
}
