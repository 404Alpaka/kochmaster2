import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/meal_planning/domain/weekly_planner.dart';

Recipe recipe(
  String id, {
  String? side,
  int minutes = 20,
  Set<String>? allergens = const {},
  Set<String>? diets = const {'Vegan'},
}) => Recipe(
  id: id,
  name: id,
  minutes: minutes,
  servings: 2,
  ingredients: const [IngredientAmount('spinach', 'Spinat', 100, 'g')],
  steps: const [],
  primarySide: side,
  verifiedAllergens: allergens,
  verifiedDiets: diets,
);
void main() {
  const planner = WeeklyPlanner();
  final first = DateTime(2026, 11, 1);
  test(
    'calendar pause includes both directions and permits exactly 30 days',
    () {
      final r = recipe('a');
      final history = [PlanningOccurrence('a', first)];
      expect(planner.repeats(r, DateTime(2026, 11, 30, 23), history), isTrue);
      expect(planner.repeats(r, DateTime(2026, 12, 1), history), isFalse);
      expect(
        planner.repeats(r, first, [
          PlanningOccurrence('a', DateTime(2026, 11, 15)),
        ]),
        isTrue,
      );
      expect(
        planner.repeats(r, first, [
          PlanningOccurrence('a', first, skipped: true),
        ]),
        isFalse,
      );
    },
  );
  test('repeat permission never relaxes allergies ratings hidden or time', () {
    final d = PlannerDay(first, maxMinutes: 30);
    expect(
      planner.eligible(
        recipe('a', allergens: null),
        d,
        const PlannerProfile(exclusions: {'Milch'}),
        [],
        allowRepeats: true,
      ),
      isFalse,
    );
    expect(
      planner.eligible(
        recipe('a'),
        d,
        const PlannerProfile(ratings: {'a': 1}, favorites: {'a'}),
        [],
        allowRepeats: true,
      ),
      isFalse,
    );
    expect(
      planner.eligible(
        recipe('a'),
        d,
        const PlannerProfile(hidden: {'a'}),
        [],
        allowRepeats: true,
      ),
      isFalse,
    );
    expect(
      planner.eligible(
        recipe('a', minutes: 31),
        d,
        const PlannerProfile(),
        [],
        allowRepeats: true,
      ),
      isFalse,
    );
  });
  test('returns partial plan and explanation without duplicating recipes', () {
    final result = planner.generate(
      catalog: [recipe('a')],
      days: {
        for (var i = 0; i < 7; i++) i: PlannerDay(first.add(Duration(days: i))),
      },
      profile: const PlannerProfile(),
    );
    expect(result.recipes.length, 1);
    expect(result.warnings, isNotEmpty);
  });
  test('beam search balances side dishes and is reproducible', () {
    final catalog = [
      for (var i = 0; i < 8; i++) recipe('$i', side: i < 4 ? 'rice' : 'potato'),
    ];
    final days = {
      for (var i = 0; i < 4; i++) i: PlannerDay(first.add(Duration(days: i))),
    };
    final a = planner.generate(
      catalog: catalog,
      days: days,
      profile: const PlannerProfile(),
      seed: 42,
    );
    final b = planner.generate(
      catalog: catalog.reversed.toList(),
      days: days,
      profile: const PlannerProfile(),
      seed: 42,
    );
    expect(
      a.recipes.map((k, v) => MapEntry(k, v.id)),
      b.recipes.map((k, v) => MapEntry(k, v.id)),
    );
    expect(a.recipes.values.where((r) => r.primarySide == 'rice').length, 2);
    for (var i = 1; i < 4; i++) {
      expect(a.recipes[i]!.primarySide, isNot(a.recipes[i - 1]!.primarySide));
    }
  });
  test('fixed meals survive and block automatic duplicate', () {
    final r = recipe('a');
    final result = planner.generate(
      catalog: [r, recipe('b')],
      days: {
        0: PlannerDay(first),
        1: PlannerDay(first.add(const Duration(days: 1))),
      },
      profile: const PlannerProfile(),
      fixed: {0: r},
    );
    expect(result.recipes[0], r);
    expect(result.recipes[1]!.id, 'b');
  });
  test('explicit ratings dominate favorites and metadata round trips', () {
    final day = PlannerDay(first);
    expect(
      planner.score(recipe('a'), day, const PlannerProfile(ratings: {'a': 5})),
      greaterThan(
        planner.score(recipe('b'), day, const PlannerProfile(favorites: {'b'})),
      ),
    );
    final restored = recipeFromSnapshot(
      recipeSnapshot(recipe('a', side: 'rice')),
    );
    expect(restored.primarySide, 'rice');
  });
  test('active time and per-day total time are binding', () {
    expect(
      planner.eligible(
        recipe('a'),
        PlannerDay(first, maxActiveMinutes: 10),
        const PlannerProfile(),
        [],
      ),
      isFalse,
    );
    final r = Recipe(
      id: 'a',
      name: 'a',
      minutes: 40,
      activeMinutes: 10,
      servings: 2,
      ingredients: const [IngredientAmount('a', 'A', 1, 'g')],
      steps: const [],
    );
    expect(
      planner.eligible(
        r,
        PlannerDay(first, maxMinutes: 30, maxActiveMinutes: 15),
        const PlannerProfile(),
        [],
      ),
      isFalse,
    );
    expect(
      planner.eligible(
        r,
        PlannerDay(first, maxMinutes: 45, maxActiveMinutes: 15),
        const PlannerProfile(),
        [],
      ),
      isTrue,
    );
  });
  test('learning requires three independent explicitly rated recipes', () {
    Recipe flavored(String id) => Recipe(
      id: id,
      name: id,
      minutes: 20,
      servings: 2,
      ingredients: const [IngredientAmount('a', 'A', 1, 'g')],
      steps: const [],
      flavors: const {'mild'},
    );
    final catalog = [for (var i = 0; i < 4; i++) flavored('$i')];
    expect(
      planner.learnedTaste(
        catalog[0],
        catalog,
        const PlannerProfile(ratings: {'1': 5, '2': 5}),
      ),
      0,
    );
    expect(
      planner.learnedTaste(
        catalog[0],
        catalog,
        const PlannerProfile(ratings: {'1': 5, '2': 5, '3': 5}),
      ),
      10,
    );
    expect(
      planner.learnedTaste(catalog[0], catalog, const PlannerProfile()),
      0,
    );
  });
  test(
    'effort feedback changes day fit without becoming a recipe exclusion',
    () {
      final r = recipe('a');
      final day = PlannerDay(first);
      expect(
        planner.score(r, day, const PlannerProfile(effortPenalties: {'a': 30})),
        lessThan(planner.score(r, day, const PlannerProfile())),
      );
      expect(
        planner.eligible(
          r,
          day,
          const PlannerProfile(effortPenalties: {'a': 30}),
          [],
        ),
        isTrue,
      );
    },
  );
}
