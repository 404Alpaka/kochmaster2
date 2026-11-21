import 'scroll_helpers.dart';

import 'dart:convert';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/shopping/domain/build_shopping_list.dart';

class MemoryWeekStore implements WeeklyPlanRepository {
  final rows = <String, Map<String, dynamic>>{};
  bool fail = false;
  bool conflict = false;
  int saveCalls = 0;
  @override
  Future<WeeklyPlan> load(DateTime week, List<Recipe> recipes) async {
    final row = rows[dateKey(week)];
    return row == null ? WeeklyPlan() : WeeklyPlan.fromJson(row, recipes);
  }

  @override
  Future<void> save(DateTime week, WeeklyPlan plan) async {
    saveCalls++;
    if (conflict) {
      throw const PostgrestException(message: 'conflict', code: '40001');
    }
    if (fail) throw StateError('offline');
    rows[dateKey(week)] =
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>;
  }
}

class LostResponseWeekStore extends MemoryWeekStore {
  bool loseResponse = false;
  @override
  Future<void> save(DateTime week, WeeklyPlan plan) async {
    await super.save(week, plan);
    if (loseResponse) throw TimeoutException('Response lost after commit');
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
      await tester.tap(find.text('Rezepte'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tomaten-Spinat');
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byTooltip('Rezeptaktionen für Tomaten-Spinat-Pasta'),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Rezeptaktionen für Tomaten-Spinat-Pasta'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zum Wochenplan hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Montag'));
      await tester.pumpAndSettle();
      expect(store.rows.length, 1);
      await tester.tap(find.text('Korb'));
      await tester.pumpAndSettle();
      if (find.text('Selbst einkaufen').evaluate().isNotEmpty) {
        await tester.tap(find.text('Selbst einkaufen').last);
        await tester.pumpAndSettle();
      }
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
      if (find.text('Selbst einkaufen').evaluate().isNotEmpty) {
        await tester.tap(find.text('Selbst einkaufen').last);
        await tester.pumpAndSettle();
      }
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
      await reveal(tester, find.text('Mo'));
      await tester.tap(find.text('Mo'));
      await tester.pumpAndSettle();
      final increase = find.byKey(const ValueKey('increase-0'));
      await reveal(tester, increase);
      await tester.pumpAndSettle();
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(find.text('3 Portionen'), findsOneWidget);
      await tester.tap(find.text('Korb'));
      await tester.pumpAndSettle();
      if (find.text('Selbst einkaufen').evaluate().isNotEmpty) {
        await tester.tap(find.text('Selbst einkaufen').last);
        await tester.pumpAndSettle();
      }
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
      if (find.text('Selbst einkaufen').evaluate().isNotEmpty) {
        await tester.tap(find.text('Selbst einkaufen').last);
        await tester.pumpAndSettle();
      }
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

  testWidgets('Versionskonflikt sperrt Speichern bis zum Neuladen', (
    tester,
  ) async {
    final store = MemoryWeekStore();
    final week = mondayOf(DateTime.now());
    await store.save(
      week,
      WeeklyPlan(meals: {0: PlannedMeal(recipes.first, 2)}),
    );
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Korb'));
    await tester.pumpAndSettle();
    if (find.text('Selbst einkaufen').evaluate().isNotEmpty) {
      await tester.tap(find.text('Selbst einkaufen').last);
      await tester.pumpAndSettle();
    }
    final tomato = find.widgetWithText(CheckboxListTile, 'Tomaten');
    store.conflict = true;
    await reveal(tester, tomato);
    await tester.tap(tomato);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(tomato).value, isFalse);
    final calls = store.saveCalls;
    store.conflict = false;
    await tester.tap(tomato);
    await tester.pumpAndSettle();
    expect(store.saveCalls, calls);
    await reveal(
      tester,
      find.byTooltip('Gespeicherten Wochenplan neu laden'),
      delta: -150,
    );
    expect(find.textContaining('Dieser Wochenplan wurde'), findsOneWidget);
    // Simulate the newer state saved by the other tab.
    store.rows[dateKey(week)] = WeeklyPlan(
      meals: {0: PlannedMeal(recipes.first, 3)},
    ).toJson();
    await tester.tap(find.byTooltip('Gespeicherten Wochenplan neu laden'));
    await tester.pumpAndSettle();
    await reveal(tester, tomato);
    await tester.tap(tomato);
    await tester.pumpAndSettle();
    expect(store.saveCalls, calls + 1);
    expect(tester.widget<CheckboxListTile>(tomato).value, isTrue);
    expect((store.rows[dateKey(week)]!['meals'] as List).single['servings'], 3);
  });

  testWidgets(
    'Verlorene Speicherantwort verlangt Neuladen statt erneutem Überschreiben',
    (tester) async {
      final store = LostResponseWeekStore();
      await store.save(
        mondayOf(DateTime.now()),
        WeeklyPlan(meals: {0: PlannedMeal(recipes.first, 2)}),
      );
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Korb'));
      await tester.pumpAndSettle();
      if (find.text('Selbst einkaufen').evaluate().isNotEmpty) {
        await tester.tap(find.text('Selbst einkaufen').last);
        await tester.pumpAndSettle();
      }
      final tomato = find.widgetWithText(CheckboxListTile, 'Tomaten');
      await reveal(tester, tomato);
      store.loseResponse = true;
      await tester.tap(tomato);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(tomato).value, isFalse);
      expect(store.rows.values.single['checked'], isNotEmpty);
      final calls = store.saveCalls;
      await tester.tap(tomato);
      await tester.pumpAndSettle();
      expect(store.saveCalls, calls);
      await reveal(
        tester,
        find.byTooltip('Gespeicherten Wochenplan neu laden'),
        delta: -150,
      );
      expect(find.text('Speicherstand unklar'), findsOneWidget);
      await tester.tap(find.byTooltip('Gespeicherten Wochenplan neu laden'));
      await tester.pumpAndSettle();
      await reveal(tester, tomato);
      expect(tester.widget<CheckboxListTile>(tomato).value, isTrue);
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
