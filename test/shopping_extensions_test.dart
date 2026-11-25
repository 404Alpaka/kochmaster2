import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/shopping/domain/shopping_pantry.dart';

import 'planning_page_test.dart' show MemoryWeekStore;
import 'scroll_helpers.dart';

void main() {
  test('Shopping stock converts and sums quantities, excludes expired stock and unknown packs', () {
    final result = compareShoppingPantry(
      const [IngredientAmount('rice', 'Reis', 800, 'g')],
      [
        {'ingredientId': 'rice', 'amount': '0.5 kg'},
        {'name': 'Reis', 'amount': '100 g'},
        {'ingredientId': 'rice', 'amount': '900 g', 'expires': '2026-11-24'},
        {'ingredientId': 'rice', 'amount': '2 Packungen'},
      ],
      DateTime(2026, 11, 25),
    ).single;
    expect(result.availableQuantity, 600);
    expect(result.missingQuantity, 200);
  });

  test(
    'Ambiguous names and incompatible units do not create stock coverage',
    () {
      final result = compareShoppingPantry(
        const [
          IngredientAmount('a', 'Milch', 100, 'ml'),
          IngredientAmount('b', 'Milch', 200, 'ml'),
        ],
        [
          {'name': 'Milch', 'amount': '1 l'},
          {'ingredientId': 'a', 'amount': '500 g'},
        ],
        DateTime(2026, 11, 25),
      );
      expect(result.map((r) => r.availableQuantity), [0, 0]);
    },
  );

  testWidgets('Copy shopping list exports actual quantities without saving', (
    tester,
  ) async {
    final recipe = DemoRecipeRepository().getAll().first;
    final week = mondayOf(DateTime.now());
    final store = MemoryWeekStore();
    store.rows[dateKey(week)] = WeeklyPlan(
      meals: {0: PlannedMeal(recipe, 4)},
      checked: {
        (recipe.ingredients.first.ingredientId, recipe.ingredients.first.unit),
      },
    ).toJson();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PlanningPage(recipes: [recipe], isDemo: true, store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Korb'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Einkaufsliste kopieren'));
    await tester.tap(find.text('Einkaufsliste kopieren'));
    await tester.pumpAndSettle();
    expect(copied, contains('Einkaufsliste ·'));
    expect(copied, contains('[x] ${recipe.ingredients.first.name}'));
    expect(copied, contains('600 g'));
    expect(store.saveCalls, 0);
  });

  testWidgets(
    'Previous week creates a cancellable draft and only confirmation saves',
    (tester) async {
      final recipes = DemoRecipeRepository().getAll();
      final week = mondayOf(DateTime.now());
      final store = MemoryWeekStore();
      store.rows[dateKey(
        DateTime(week.year, week.month, week.day - 7),
      )] = WeeklyPlan(
        meals: {
          0: PlannedMeal(recipes.first, 4),
          1: PlannedMeal(recipes.last, 2, preparedMealId: 'leftovers'),
        },
        checked: {
          (
            recipes.first.ingredients.first.ingredientId,
            recipes.first.ingredients.first.unit,
          ),
        },
      ).toJson();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PlanningPage(recipes: recipes, isDemo: true, store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      final reuse = find.text('Vorwoche als Entwurf verwenden');
      await reveal(tester, reuse);
      await tester.tap(reuse);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(store.saveCalls, 0);
      await tester.tap(reuse);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entwurf erstellen'));
      await tester.pumpAndSettle();
      expect(store.saveCalls, 0);
      await tester.tap(find.text('Wochenplan bestätigen'));
      await tester.pumpAndSettle();
      expect(store.saveCalls, 1);
      final saved = WeeklyPlan.fromJson(store.rows[dateKey(week)]!, recipes);
      expect(saved.meals.length, 1);
      expect(saved.meals[0]!.servings, 4);
      expect(saved.checked, isEmpty);
    },
  );
}
