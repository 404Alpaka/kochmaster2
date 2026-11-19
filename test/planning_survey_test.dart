import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/meal_planning/presentation/food_preferences_page.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

import 'planning_page_test.dart' show MemoryWeekStore;
import 'scroll_helpers.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'One preference page, safe proposal and confirmation at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemoryWeekStore();
        final recipes = DemoRecipeRepository().getAll();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: PlanningPage(recipes: recipes, isDemo: true, store: store),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> tap(Finder finder, {double delta = 150}) async {
          if (finder.evaluate().isEmpty)
            await reveal(tester, finder, delta: delta);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await tap(find.text('Plan'));
        await tap(find.byKey(const ValueKey('week-primary-action')));
        expect(find.byType(FoodPreferencesPage), findsOneWidget);
        await tap(find.widgetWithText(ChoiceChip, 'Vegetarisch'));
        await tap(find.widgetWithText(FilterChip, 'Erdnüsse'));
        await tap(find.text('Präferenzen übernehmen'));
        expect(find.textContaining('0 Abendessen'), findsOneWidget);
        expect(store.saveCalls, 0);
        await tap(find.text('Präferenzen ändern'), delta: -150);
        await tap(find.widgetWithText(ChoiceChip, 'Ohne Einschränkung'));
        await tap(find.widgetWithText(FilterChip, 'Erdnüsse'));
        await tap(find.text('Präferenzen übernehmen'));
        expect(find.text('Deine Woche. Dein Mix.'), findsOneWidget);
        expect(
          find.text('Dein Budget gilt für die geplanten Abendessen.'),
          findsNothing,
        );
        expect(
          find.text('Deine Vorgaben bleiben deine Vorgaben.'),
          findsNothing,
        );
        await tap(find.text('Wochenplan bestätigen'));
        final key = dateKey(mondayOf(DateTime.now()));
        expect(WeeklyPlan.fromJson(store.rows[key]!, recipes).meals.length, 2);
        await tap(find.text('Wochenplan bearbeiten'));
        await tap(find.byKey(const ValueKey('proposal-free-0')));
        await tap(find.text('Bearbeiten abbrechen'), delta: -150);
        expect(WeeklyPlan.fromJson(store.rows[key]!, recipes).meals.length, 2);
        await tap(find.text('Wochenplan bearbeiten'));
        await tap(find.byKey(const ValueKey('proposal-free-0')));
        await tap(find.text('Wochenplan bestätigen'));
        expect(WeeklyPlan.fromJson(store.rows[key]!, recipes).meals.length, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
