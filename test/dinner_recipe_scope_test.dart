import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/meal_planning/domain/weekly_planner.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';

Recipe sample(String id, String name, {Set<String> categories = const {}}) =>
    Recipe(
      id: id,
      name: name,
      minutes: 20,
      servings: 2,
      ingredients: const [IngredientAmount('oats', 'Haferflocken', 100, 'g')],
      steps: const ['Kochen'],
      categories: categories,
    );
void main() {
  test(
    'dinner scope excludes breakfast categories and untagged cereal dishes',
    () {
      expect(
        isDinnerRecipe(
          sample('a', 'Rührei mit Toast', categories: {'breakfast'}),
        ),
        isFalse,
      );
      for (final name in [
        'Apfel-Porridge',
        'Proddige',
        'Overnight Oats mit Banane',
        'Birnen-Müsli',
        'Haferbrei',
      ]) {
        expect(isDinnerRecipe(sample('b', name)), isFalse, reason: name);
      }
      expect(
        isDinnerRecipe(
          sample('c', 'Herzhafte Gemüsebratlinge', categories: {'main'}),
        ),
        isTrue,
      );
    },
  );
  test(
    'favorites and repeat permission cannot select breakfast for dinner',
    () {
      final breakfast = sample('breakfast', 'Porridge');
      final dinner = sample('dinner', 'Gemüsebratlinge');
      final result = const WeeklyPlanner().generate(
        catalog: [breakfast, dinner],
        days: {
          0: PlannerDay(DateTime(2026, 11, 23)),
          1: PlannerDay(DateTime(2026, 11, 24)),
        },
        profile: const PlannerProfile(
          favorites: {'breakfast'},
          ratings: {'breakfast': 5},
        ),
        allowRepeats: true,
      );
      expect(result.recipes.values.map((r) => r.id), ['dinner']);
    },
  );
  testWidgets(
    'discovery and search hide breakfast and keep savory oat dishes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PlanningPage(
            isDemo: true,
            recipes: [
              sample('breakfast', 'Bananen-Porridge'),
              sample('toast', 'Frühstückstoast', categories: {'breakfast'}),
              sample('dinner', 'Gemüsebratlinge'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Porridge'), findsNothing);
      await tester.tap(find.text('Rezepte'));
      await tester.pumpAndSettle();
      expect(find.text('Frühstück'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Porridge');
      await tester.pumpAndSettle();
      expect(find.text('Bananen-Porridge'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Gemüsebratlinge');
      await tester.pumpAndSettle();
      expect(find.text('Gemüsebratlinge'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
