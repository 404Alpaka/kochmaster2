import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('Leerer und gefüllter Vorrat bei $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = bool.fromEnvironment('CAPTURE_DESIGN');
      if (capture) {
        await tester.runAsync(() async {
          await ui.loadFontFromList(
            await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
            fontFamily: 'Roboto',
          );
          await ui.loadFontFromList(
            await File(
              'C:/Users/klaeh/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes(),
            fontFamily: 'MaterialIcons',
          );
        });
      }
      const preview = ValueKey('pantry-preview');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: preview,
            child: PlanningPage(
              isDemo: true,
              recipes: DemoRecipeRepository().getAll(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vorrat'));
      await tester.pumpAndSettle();
      expect(find.text('Dein Vorrat ist noch leer'), findsOneWidget);
      expect(find.text('Kassenbon scannen'), findsOneWidget);
      expect(find.text('Barcode scannen'), findsOneWidget);
      expect(find.byTooltip('Vorrat hinzufügen'), findsNothing);
      Future<void> snapshot(String state) async {
        if (!capture || width != 390) return;
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(preview))
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/design').create(recursive: true);
          await File('build/design/pantry-$state.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await snapshot('empty');
      await tester.scrollUntilVisible(
        find.text('Beispiel-Bon ausprobieren'),
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beispiel-Bon ausprobieren'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Zuordnung bestätigen'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Zuordnung bestätigen')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zuordnung bestätigen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 Produkte zum Vorrat hinzufügen'));
      await tester.pumpAndSettle();
      expect(find.text('Dein Vorrat ist noch leer'), findsNothing);
      expect(find.text('3 Zutaten laufen bald ab'), findsOneWidget);
      expect(find.text('BALD ABLAUFEND'), findsOneWidget);
      expect(find.text('Babyspinat'), findsOneWidget);
      expect(find.text('Morgen'), findsOneWidget);
      expect(find.byTooltip('Vorrat hinzufügen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await snapshot('filled');
      await tester.tap(find.text('Trocken'));
      await tester.pumpAndSettle();
      expect(find.text('Basmatireis'), findsOneWidget);
      expect(find.text('Babyspinat'), findsNothing);
      expect(find.text('BALD ABLAUFEND'), findsNothing);
      await tester.tap(find.text('Gekocht'));
      await tester.pumpAndSettle();
      expect(
        find.text('Hier ist noch Platz. Füge neue Vorräte hinzu.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Vorrat hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manuell hinzufügen'));
      await tester.pumpAndSettle();
      expect(find.text('Lebensmittel erfassen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
