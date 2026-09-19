// Renders the AppIcon mark (lib/widgets/app_icon.dart) to the PNGs that
// flutter_launcher_icons reads (see the flutter_launcher_icons block in
// pubspec.yaml). Re-run after changing the mark:
//
//   docker compose run --rm --no-deps app sh -c \
//     "flutter pub get && flutter test tool/render_app_icon_test.dart && dart run flutter_launcher_icons"
//
// flutter_launcher_icons 0.14.4 also rewrites
// ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS to `AppIcon`
// in ios/Runner.xcodeproj/project.pbxproj (a yes/no setting), which is wrong —
// run `git checkout ios/Runner.xcodeproj/project.pbxproj` afterwards.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bookmarked/theme.dart';
import 'package:bookmarked/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _canvas = 1024.0;

Future<void> _render(
  WidgetTester tester, {
  required String path,
  required double markFraction,
  Color? background,
}) async {
  tester.view.physicalSize = const Size(_canvas, _canvas);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Container(
          width: _canvas,
          height: _canvas,
          color: background,
          alignment: Alignment.center,
          child: AppIcon(size: _canvas * markFraction),
        ),
      ),
    ),
  );

  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  // Full-bleed icon (iOS, and legacy pre-Android-8 launchers): the mark on the
  // app's paper colour, with room to breathe inside the rounded mask.
  testWidgets('render icon.png', (tester) => _render(
        tester,
        path: 'assets/icon/icon.png',
        markFraction: 0.80,
        background: AppColors.paper,
      ));

  // Android adaptive foreground: transparent. flutter_launcher_icons insets
  // this layer by 16% per side (mipmap-anydpi-v26/ic_launcher.xml), so at 0.75
  // the bookmark's corners land just inside the 66dp-of-108dp safe zone that
  // circular and squircle masks can crop to. The background colour comes from
  // adaptive_icon_background in pubspec.yaml.
  testWidgets('render icon_foreground.png', (tester) => _render(
        tester,
        path: 'assets/icon/icon_foreground.png',
        markFraction: 0.75,
      ));
}
