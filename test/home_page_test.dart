import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('Startseite und Navigation bei $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
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
      const preview = ValueKey('home-preview');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: preview,
            child: PlanningPage(
              isDemo: true,
              recipes: DemoRecipeRepository().getAll(),
              user: User.fromJson({
                'id': 'test-user',
                'aud': 'authenticated',
                'app_metadata': <String, dynamic>{},
                'user_metadata': <String, dynamic>{'first_name': 'Fabian'},
                'created_at': '2026-11-18T12:00:00Z',
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hallo, Fabian!'), findsOneWidget);
      expect(find.text('Wochenplan'), findsOneWidget);
      expect(find.text('Kochen starten'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390 && const bool.fromEnvironment('CAPTURE_DESIGN')) {
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(preview))
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/design').create(recursive: true);
          await File('build/design/home-390.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.text('Haushalt'), findsNothing);
      expect(find.text('Hallo, Fabian!'), findsOneWidget);
      await tester.tap(find.text('Wochenplan'));
      await tester.pumpAndSettle();
      expect(find.text('Hallo, Fabian!'), findsNothing);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zum Haushalt'));
      await tester.pumpAndSettle();
      expect(find.text('Zusammen isst’s besser.'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Rezept ansehen').first,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byTooltip('Rezept ansehen').first);
      await tester.tap(find.byTooltip('Rezept ansehen').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Jetzt kochen'), findsOneWidget);
      expect(find.text('Nicht mehr vorschlagen'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Ausblenden'), findsOneWidget);
      await tester.scrollUntilVisible(find.byTooltip('Mehr Portionen'), 160,
        scrollable: find.byType(Scrollable).first);
      expect(find.byTooltip('Mehr Portionen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
