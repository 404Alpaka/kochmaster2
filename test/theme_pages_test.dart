import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [390.0, 1280.0]) {
      testWidgets('Main pages in ${dark ? 'dark' : 'light'} mode at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const capture = bool.fromEnvironment('CAPTURE_DESIGN');
        if (capture) {
          await tester.runAsync(() async {
            await ui.loadFontFromList(
              await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
              fontFamily: 'Ahem',
            );
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
        const preview = ValueKey('theme-preview');
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: RepaintBoundary(
              key: preview,
              child: PlanningPage(
                recipes: DemoRecipeRepository().getAll(),
                isDemo: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final tab in ['Start', 'Rezepte', 'Plan', 'Vorrat', 'Korb']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: tab);
          expect(
            find.byKey(const ValueKey('bottom-navigation-surface')),
            findsOneWidget,
          );
          if (capture && width == 390) {
            await tester.runAsync(() async {
              final image = await tester
                  .renderObject<RenderRepaintBoundary>(find.byKey(preview))
                  .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/design').create(recursive: true);
              await File(
                'build/design/theme-${dark ? 'dark' : 'light'}-$tab.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
