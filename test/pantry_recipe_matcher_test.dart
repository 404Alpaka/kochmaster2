import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/meal_planning/domain/pantry_recipe_matcher.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';

void main() {
  Recipe recipe({int servings = 2}) => Recipe(
    id: 'test-recipe',
    name: 'Kartoffelpfanne',
    minutes: 30,
    servings: servings,
    ingredients: const [
      IngredientAmount('kartoffeln', 'Kartoffeln', 400, 'g'),
      IngredientAmount('eier', 'Eier', 2, 'Stück'),
      IngredientAmount('milch', 'Milch', 200, 'ml'),
      IngredientAmount('kaese', 'Käse', 150, 'g'),
    ],
    steps: const ['Zubereiten'],
  );

  test('skaliert Mengen auf gewählte Portionszahl', () {
    final match = const PantryRecipeMatcher()
        .match(recipes: [recipe()], pantry: const [], portions: 4)
        .single;
    expect(match.matches.first.requiredQuantity, 800);
    expect(match.missingCount, 4);
  });

  test('rechnet kg, l und Stück um und erkennt Teilvorrat', () {
    final match = const PantryRecipeMatcher()
        .match(
          recipes: [recipe()],
          pantry: const [
            {
              'name': 'Kartoffeln',
              'ingredientId': 'kartoffeln',
              'amount': '0,5 kg',
            },
            {'name': 'Eier', 'ingredientId': 'eier', 'amount': '1 Stück'},
            {'name': 'Milch', 'ingredientId': 'milch', 'amount': '100 ml'},
            {'name': 'Käse', 'ingredientId': 'kaese', 'amount': '100 g'},
          ],
          portions: 2,
        )
        .single;
    expect(match.availableCount, 4);
    expect(match.matches[0].state, PantryIngredientState.full);
    expect(match.matches[1].state, PantryIngredientState.partial);
    expect(match.matches[2].state, PantryIngredientState.partial);
    expect(match.matches[3].state, PantryIngredientState.partial);
  });

  test('unbekannte Einheiten werden nicht als vorhanden gewertet', () {
    final match = const PantryRecipeMatcher()
        .match(
          recipes: [recipe()],
          pantry: const [
            {
              'name': 'Kartoffeln',
              'ingredientId': 'kartoffeln',
              'amount': '2 Packungen',
            },
          ],
          portions: 2,
        )
        .single;
    expect(match.matches.first.state, PantryIngredientState.missing);
  });

  test('sortiert sofort, fast und weitere Rezepte', () {
    final one = recipe();
    final other = Recipe(
      id: 'other',
      name: 'Andere Pfanne',
      minutes: 20,
      servings: 2,
      ingredients: const [IngredientAmount('x', 'X', 1, 'Stück')],
      steps: const ['Kochen'],
    );
    final matches = const PantryRecipeMatcher().match(
      recipes: [other, one],
      pantry: const [
        {'name': 'Kartoffeln', 'ingredientId': 'kartoffeln', 'amount': '400 g'},
        {'name': 'Eier', 'ingredientId': 'eier', 'amount': '2 Stück'},
        {'name': 'Milch', 'ingredientId': 'milch', 'amount': '200 ml'},
        {'name': 'Käse', 'ingredientId': 'kaese', 'amount': '150 g'},
      ],
      portions: 2,
    );
    expect(matches.first.recipe.id, 'test-recipe');
  });
}
