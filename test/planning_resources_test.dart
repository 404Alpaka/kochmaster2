import 'package:kochmaster/features/account_data/data/account_data_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/meal_planning/domain/planning_resources.dart';
import 'package:kochmaster/features/meal_planning/domain/planning_diner.dart';
import 'package:kochmaster/features/meal_planning/domain/weekly_planner.dart';

Recipe meal(
  String id, {
  double quantity = 100,
  String unit = 'g',
  String? costClass,
  Set<String>? allergens = const {},
  Set<String>? diets = const {'Vegan', 'Vegetarisch'},
}) => Recipe(
  id: id,
  name: id,
  minutes: 20,
  servings: 2,
  ingredients: [IngredientAmount('spinach', 'Spinat', quantity, unit)],
  steps: const [],
  costClass: costClass,
  verifiedAllergens: allergens,
  verifiedDiets: diets,
);
void main() {
  final monday = DateTime(2026, 11, 23);
  const planner = WeeklyPlanner();
  test(
    'stock is allocated chronologically once, including portion scaling',
    () {
      final resource = PlanningResources(
        stock: [
          PlanningStock(ingredientId: 'spinach', quantity: 0.15, unit: 'kg'),
        ],
      );
      final scores = resource.pantryScores(
        {1: meal('later'), 0: meal('first')},
        {1: (monday.add(const Duration(days: 1)), 2), 0: (monday, 2)},
      );
      expect(scores[0], 100);
      expect(scores[1], 75);
      expect(resource.stock.single.quantity, 0.15);
      expect(resource.pantryScores({0: meal('a')}, {0: (monday, 4)})[0], 87.5);
    },
  );
  test(
    'earliest expiry is consumed first and expired lots never give a bonus',
    () {
      final resources = PlanningResources(
        stock: [
          PlanningStock(ingredientId: 'spinach', quantity: 100, unit: 'g'),
          PlanningStock(
            ingredientId: 'spinach',
            quantity: 100,
            unit: 'g',
            expires: monday,
          ),
        ],
      );
      expect(
        resources
            .pantryScores(
              {0: meal('a'), 1: meal('b')},
              {0: (monday, 2), 1: (monday.add(const Duration(days: 1)), 2)},
            )
            .values,
        everyElement(100),
      );
      final expired = PlanningResources(
        stock: [
          PlanningStock(
            ingredientId: 'spinach',
            quantity: 100,
            unit: 'g',
            expires: monday.subtract(const Duration(days: 1)),
          ),
        ],
      );
      expect(expired.pantryScores({0: meal('a')}, {0: (monday, 2)})[0], 50);
    },
  );
  test(
    'unknown units, quantities and incompatible dimensions are never guessed',
    () {
      expect(planningQuantity(double.nan, 'g'), isNull);
      expect(planningQuantity(-1, 'g'), isNull);
      expect(planningQuantity(1, 'Dose'), isNull);
      const resources = PlanningResources(
        stock: [PlanningStock(ingredientId: 'spinach', quantity: 1, unit: 'l')],
      );
      expect(resources.pantryScores({0: meal('a')}, {0: (monday, 2)})[0], 50);
      expect(const PlanningResources().hasStock, isFalse);
    },
  );
  test('duplicate ingredient rows share one combined requirement', () {
    final recipe = Recipe(
      id: 'a',
      name: 'a',
      minutes: 20,
      servings: 2,
      ingredients: const [
        IngredientAmount('spinach', 'Spinat', 100, 'g'),
        IngredientAmount('spinach', 'Spinat', 100, 'g'),
      ],
      steps: const [],
    );
    const resources = PlanningResources(
      stock: [PlanningStock(ingredientId: 'spinach', quantity: 100, unit: 'g')],
    );
    expect(resources.pantryScores({0: recipe}, {0: (monday, 2)})[0], 75);
  });
  test('budget estimates scale by portions and missing data is neutral', () {
    const resources = PlanningResources(
      budget: 20,
      costPerServing: {'a': 2, 'b': 12},
    );
    expect(resources.estimatedCost(meal('a'), 4), 8);
    expect(resources.estimatedCost(meal('c'), 4), isNull);
    expect(resources.budgetScore(meal('c'), 2, 4), 50);
    expect(
      resources.budgetScore(meal('a'), 2, 4),
      greaterThan(resources.budgetScore(meal('b'), 2, 4)),
    );
    expect(const PlanningResources(budget: double.nan).hasBudget, isFalse);
  });
  test('coarse cost classes affect preference without inventing prices', () {
    const resources = PlanningResources(costClass: 'low');
    expect(
      resources.budgetScore(meal('a', costClass: 'low'), 2, 4),
      greaterThan(resources.budgetScore(meal('b', costClass: 'high'), 2, 4)),
    );
    expect(resources.estimatedCost(meal('a', costClass: 'low'), 2), isNull);
    expect(resources.budgetScore(meal('a', costClass: 'unknown'), 2, 4), 50);
  });
  test('resource fit influences selection and exclusions still dominate', () {
    final resources = PlanningResources(
      stock: [PlanningStock(ingredientId: 'spinach', quantity: 1, unit: 'kg')],
      budget: 10,
      costPerServing: {'a': 1, 'b': 10},
    );
    final result = planner.generate(
      catalog: [meal('b'), meal('a')],
      days: {0: PlannerDay(monday)},
      profile: PlannerProfile(resources: resources),
    );
    expect(result.recipes[0]!.id, 'a');
    expect(result.reasons[0]!.any((r) => r.contains('Vorräte')), isTrue);
    final blocked = planner.generate(
      catalog: [
        meal('a', allergens: {'Milch'}),
      ],
      days: {0: PlannerDay(monday)},
      profile: PlannerProfile(resources: resources, exclusions: {'Milch'}),
      allowRepeats: true,
    );
    expect(blocked.recipes, isEmpty);
  });
  test(
    'incomplete budget is identified and never presented as a zero price',
    () {
      final result = planner.generate(
        catalog: [meal('a')],
        days: {0: PlannerDay(monday)},
        profile: const PlannerProfile(resources: PlanningResources(budget: 10)),
      );
      expect(
        result.warnings.any((w) => w.contains('nicht vollständig prüfen')),
        isTrue,
      );
      expect(result.reasons[0]!.any((w) => w.contains('0,00')), isFalse);
    },
  );
  test(
    'every participating diner must have known and compatible restrictions',
    () {
      const diners = [
        PlanningDiner(id: 'a', name: 'A', confirmed: true, diet: 'Vegan'),
        PlanningDiner(
          id: 'b',
          name: 'B',
          confirmed: true,
          exclusions: {'Milch'},
        ),
      ];
      final profile = PlannerProfile(diners: diners, favorites: {'a'});
      expect(
        planner.eligible(
          meal('a', allergens: {'Milch'}),
          PlannerDay(monday),
          profile,
          [],
          allowRepeats: true,
        ),
        isFalse,
      );
      expect(
        planner.eligible(
          meal('a', diets: {'Vegetarisch'}),
          PlannerDay(monday),
          profile,
          [],
        ),
        isFalse,
      );
      expect(
        planner.eligible(meal('a'), PlannerDay(monday), profile, []),
        isTrue,
      );
      expect(
        planner.eligible(
          meal('a', allergens: null),
          PlannerDay(monday),
          profile,
          [],
        ),
        isFalse,
      );
    },
  );
  test('unconfirmed diners block proposals with actionable reason', () {
    final result = planner.generate(
      catalog: [meal('a')],
      days: {0: PlannerDay(monday)},
      profile: const PlannerProfile(
        diners: [PlanningDiner(id: 'a', name: 'Anna')],
      ),
    );
    expect(result.recipes, isEmpty);
    expect(
      result.warnings.any(
        (w) => w.contains('Anna') && w.contains('Ernährungsregeln'),
      ),
      isTrue,
    );
    expect(
      planner.eligible(
        meal('a'),
        PlannerDay(monday),
        const PlannerProfile(
          diners: [
            PlanningDiner(id: 'a', name: 'Anna', participates: false),
            PlanningDiner(id: 'b', name: 'Ben', confirmed: true),
          ],
        ),
        [],
      ),
      isTrue,
    );
  });
  test('diner declarations round trip independently of personal ratings', () {
    const diner = PlanningDiner(
      id: 'a',
      name: 'Anna',
      confirmed: true,
      diet: 'Vegan',
      exclusions: {'Soja'},
    );
    final restored = PlanningDiner.fromJson(
      diner.id,
      diner.name,
      diner.toJson(),
    );
    expect(restored.rulesKnown, isTrue);
    expect(restored.diet, 'Vegan');
    expect(restored.exclusions, {'Soja'});
    expect(PlanningDiner.fromJson('a', 'A', {}).rulesKnown, isFalse);
  });
  test('resource sharing never includes private taste signals or notes', () {
    final personal = {
      'pantry': [],
      'recipeCostEstimates': {'private': 1},
      'householdDinerRules': {},
      'budgetCostClass': 'high',
    };
    final current = {
      'pantry': [],
      'recipeCostEstimates': {'shared': 2},
      'householdDinerRules': {
        'a': const PlanningDiner(id: 'a', name: 'A', confirmed: true).toJson(),
      },
      'budgetCostClass': 'low',
      'recipeRatings': {'a': 5},
      'recipeNotes': {'a': 'Private note'},
      'personalExclusions': ['Soja'],
    };
    final shared = sharedAccountData(current);
    expect(shared['recipeCostEstimates'], {'shared': 2});
    for (final key in ['recipeRatings', 'recipeNotes', 'personalExclusions']) {
      expect(shared.containsKey(key), isFalse);
    }
    final restored = privateAccountData(
      current,
      personal,
      householdActive: true,
    );
    expect(restored['recipeCostEstimates'], {'private': 1});
    expect(restored['budgetCostClass'], 'high');
    expect(restored['recipeNotes'], {'a': 'Private note'});
  });
}
