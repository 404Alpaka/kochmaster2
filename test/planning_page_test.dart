import 'scroll_helpers.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/shopping/domain/build_shopping_list.dart';

class MemoryWeekStore implements WeeklyPlanRepository {
  final rows = <String, Map<String, dynamic>>{};
  bool fail = false;
  @override
  Future<WeeklyPlan> load(DateTime week, List<Recipe> recipes) async {
    final row = rows[dateKey(week)];
    return row == null ? WeeklyPlan() : WeeklyPlan.fromJson(row, recipes);
  }

  @override
  Future<void> save(DateTime week, WeeklyPlan plan) async {
    if (fail) throw StateError('offline');
    rows[dateKey(week)] =
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>;
  }
}

void main() {
  final recipes = DemoRecipeRepository().getAll();
  Widget app(MemoryWeekStore store) => MaterialApp(
    home: PlanningPage(recipes: recipes, isDemo: false, store: store),
  );

  testWidgets(
    'Plan und Einkauf überleben Neuaufbau und Wochenwechsel; Portionen skalieren',
    (tester) async {
      final store = MemoryWeekStore();
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.widgetWithText(FilledButton, 'Wochenplan').first,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Wochenplan').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Montag'));
      await tester.pumpAndSettle();
      expect(store.rows.length, 1);
      await tester.tap(find.text('Korb'));
      await tester.pumpAndSettle();
      final tomato = find.widgetWithText(CheckboxListTile, 'Tomaten');
      await reveal(tester, tomato);
      await tester.pumpAndSettle();
      await tester.tap(tomato);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(tomato).value, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Korb'));
      await tester.pumpAndSettle();
      await reveal(tester, tomato);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(tomato).value, isTrue);
      await reveal(tester, find.byTooltip('Nächste Woche'), delta: -150);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nächste Woche'));
      await tester.pumpAndSettle();
      expect(find.text('Tomaten'), findsNothing);
      await tester.tap(find.byTooltip('Vorherige Woche'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      final increase = find.byKey(const ValueKey('increase-0'));
      await reveal(tester, increase);
      await tester.pumpAndSettle();
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(find.text('3 Portionen'), findsOneWidget);
      await tester.tap(find.text('Korb'));
      await tester.pumpAndSettle();
      await reveal(tester, tomato);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(tomato).value, isFalse);
      expect(find.text('450.0 g'), findsOneWidget);
    },
  );

  testWidgets(
    'Speicherfehler täuscht keinen gespeicherten Einkaufsstatus vor',
    (tester) async {
      final store = MemoryWeekStore();
      await store.save(
        mondayOf(DateTime.now()),
        WeeklyPlan(meals: {0: PlannedMeal(recipes.first, 2)}),
      );
      store.fail = true;
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Korb'));
      await tester.pumpAndSettle();
      final tomato = find.widgetWithText(CheckboxListTile, 'Tomaten');
      await reveal(tester, tomato);
      await tester.pumpAndSettle();
      await tester.tap(tomato);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(tomato).value, isFalse);
      await reveal(tester, find.text('Nicht gespeichert'), delta: -150);
      expect(find.text('Nicht gespeichert'), findsOneWidget);
      expect(store.rows.values.single['checked'], isEmpty);
    },
  );

  test('Unveränderte Einkaufspositionen bleiben beim Planen erledigt', () {
    final before = [PlannedMeal(recipes[0], 2)];
    final after = [...before, PlannedMeal(recipes[1], 2)];
    expect(
      retainCheckedItems(before, after, {('pasta', 'g'), ('tomato', 'g')}),
      {('pasta', 'g')},
    );
    expect(retainCheckedItems(before, [], {('pasta', 'g')}), isEmpty);
  });
}
