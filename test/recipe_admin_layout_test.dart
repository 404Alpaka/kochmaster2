import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/recipes/presentation/admin_recipes_page.dart';

import 'admin_recipes_test.dart' show AdminMemoryStore;

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('Recipe catalog image and layout at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
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
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: const ValueKey('editor-preview'),
            child: AdminRecipesPage(
              repository: AdminMemoryStore()
                ..items.addAll([
                  for (final r in DemoRecipeRepository().getAll())
                    AdminRecipe(r, published: true),
                ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
        await tester.runAsync(() async {
          final context = tester.element(find.byType(Scaffold));
          await precacheImage(
            const AssetImage('assets/images/pasta.jpg'),
            context,
          );
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('editor-preview')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/design').create(recursive: true);
          await File('build/design/recipe-admin-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
}
