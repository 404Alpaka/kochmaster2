import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_editor_page.dart';

import 'admin_recipes_test.dart' show AdminMemoryStore;

class LayoutStore extends AdminMemoryStore {
  @override
  Future<List<CatalogIngredient>> ingredients() async => [
    for (final i in DemoRecipeRepository().getAll().first.ingredients)
      CatalogIngredient(i.ingredientId, i.name),
  ];
}

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('Recipe editor image and layout at $width', (tester) async {
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
            child: RecipeEditorPage(
              repository: LayoutStore(),
              existing: AdminRecipe(
                DemoRecipeRepository().getAll().first,
                published: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-recipe-image')), findsOneWidget);
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
          await File('build/design/recipe-editor-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      for (
        var i = 0;
        i < 30 && find.text('Rezept speichern').evaluate().isEmpty;
        i++
      ) {
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(find.text('Rezept speichern'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
