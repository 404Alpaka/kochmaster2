import 'scroll_helpers.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/app/kochmaster_app.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('Design und Rezeptdetails bei $width Pixeln', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
        await tester.runAsync(() async {
          await ui.loadFontFromList(
            await File(
              'C:/Users/klaeh/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes(),
            fontFamily: 'MaterialIcons',
          );
          await ui.loadFontFromList(
            await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
            fontFamily: 'Roboto',
          );
        });
      }
      const preview = ValueKey('preview');
      await tester.pumpWidget(
        const RepaintBoundary(key: preview, child: KochmasterApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rezepte'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
        await tester.runAsync(() async {
          final context = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/images/pasta.jpg'), context);
          if (context.mounted) await precacheImage(const AssetImage('assets/images/rice.jpg'), context);
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(preview),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/design').create(recursive: true);
          await File('build/design/recipes-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.enterText(find.byType(TextField), 'Spinat');
      await tester.pumpAndSettle();
      await reveal(tester, find.text('1 von 2 Rezepten'));
      expect(find.text('1 von 2 Rezepten'), findsOneWidget);
      final details = find.byTooltip('Rezept ansehen').first;
      await reveal(tester, details, delta: -150);
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Entdecken'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await reveal(tester, find.byTooltip('Mehr Portionen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mehr Portionen'));
      await tester.pumpAndSettle();
      expect(find.text('3 Personen'), findsOneWidget);
      await reveal(tester, find.text('So kommt es auf den Tisch'));
      expect(find.text('So kommt es auf den Tisch'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final add = find.text('Zum Wochenplan hinzufügen');
      await reveal(tester, add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Montag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('1 von 7 Tagen'));
      expect(find.text('1 von 7 Tagen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
