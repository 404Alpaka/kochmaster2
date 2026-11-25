import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

import 'planning_page_test.dart' show MemoryWeekStore;
import 'scroll_helpers.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('Leerer und Beispiel-Korb bei $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
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
      const preview = ValueKey('shopping-preview');
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
      await tester.tap(find.text('Korb'));
      await tester.pumpAndSettle();
      expect(find.text('Dein Korb ist noch leer'), findsOneWidget);
      expect(find.text('Gesamt'), findsNothing);
      Future<void> snapshot(String state) async {
        if (!const bool.fromEnvironment('CAPTURE_DESIGN') || width != 390) {
          return;
        }
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(preview))
              .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/design').create(recursive: true);
          await File('build/design/cart-$state.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await snapshot('empty');
      await reveal(tester, find.text('Zum Wochenplan'));
      await tester.tap(find.text('Zum Wochenplan'));
      await tester.pumpAndSettle();
      expect(find.text('Deine Woche'), findsOneWidget);
      await tester.tap(find.text('Korb'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Beispiel-Vergleich ansehen'));
      await tester.tap(find.text('Beispiel-Vergleich ansehen'));
      await tester.pumpAndSettle();
      expect(find.text('Supermarktvergleich'), findsOneWidget);
      expect(find.text('Beispielwerte'), findsOneWidget);
      expect(find.text('Gesamt · Beispiel'), findsOneWidget);
      expect(find.text('62,40 €'), findsNWidgets(2));
      expect(
        find.text('5,40 € gespart gegenüber dem teuersten Markt'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await snapshot('filled');
      await tester.tap(find.text('Frischmarkt'));
      await tester.pumpAndSettle();
      expect(find.text('65,10 €'), findsNWidgets(2));
      await tester.tap(find.text('Liefern lassen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Lieferung prüfen'));
      await tester.pumpAndSettle();
      expect(find.text('Fast am Esstisch.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Plan-Korb enthält echte Mengen und übernimmt Einkaufsstatus', (
    tester,
  ) async {
    final recipe = DemoRecipeRepository().getAll().first;
    final store = MemoryWeekStore();
    final week = mondayOf(DateTime.now());
    store.rows[dateKey(week)] = WeeklyPlan(meals: {0: PlannedMeal(recipe, 4)})
        .toJson();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PlanningPage(recipes: [recipe], isDemo: true, store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Korb'));
    await tester.pumpAndSettle();
    expect(find.text('Dein Korb ist noch leer'), findsNothing);
    expect(find.text('Deine Einkaufsliste'), findsOneWidget);
    expect(find.text('Supermarktvergleich'), findsNothing);
    expect(find.text('Preis offen'), findsNothing);
    final item = find.byType(CheckboxListTile).first;
    await reveal(tester, item);
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(store.saveCalls, 1);
    expect((store.rows[dateKey(week)]!['checked'] as List), hasLength(1));
    await reveal(tester, find.text('Händlervergleich ansehen · Demo'));
    await tester.tap(find.text('Händlervergleich ansehen · Demo'));
    await tester.pumpAndSettle();
    expect(find.text('Supermarktvergleich'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Deine Einkaufsliste'), findsOneWidget);
    await reveal(tester, item);
    expect(tester.widget<CheckboxListTile>(item).value, isTrue);
    expect(store.saveCalls, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dein Alltag. Gut geplant.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
