import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/data/supabase_recipe_repository.dart';

void main() {
  Recipe make(
    double quantity, {
    String label = 'Reis',
    String unit = 'g',
    int servings = 2,
  }) => Recipe(
    id: 'r',
    name: 'Reis',
    imageUrl: 'https://example.com/rice.jpg',
    minutes: 15,
    servings: servings,
    ingredients: [
      IngredientAmount('rice', label, quantity, unit, stepKey: 'stable'),
    ],
    steps: ['Koche {{ingredient:stable}} 15 Minuten.'],
  );
  test('Linked quantities follow recipe edits and selected portions', () {
    expect(renderedRecipeSteps(make(100), portions: 4), [
      'Koche 200 g Reis 15 Minuten.',
    ]);
    expect(
      renderedRecipeSteps(make(150, label: 'Nudeln', unit: 'ml'), portions: 3),
      ['Koche 225 ml Nudeln 15 Minuten.'],
    );
    expect(renderedRecipeSteps(make(300, servings: 4), portions: 2), [
      'Koche 150 g Reis 15 Minuten.',
    ]);
  });
  test('Links and images survive saved snapshots and catalog rows', () {
    final restored = recipeFromSnapshot(recipeSnapshot(make(125)));
    expect(restored.imageUrl, 'https://example.com/rice.jpg');
    expect(renderedRecipeSteps(restored, portions: 4), [
      'Koche 250 g Reis 15 Minuten.',
    ]);
    final row = recipeFromRow({
      'id': 'r',
      'name': 'Reis',
      'prep_minutes': 15,
      'servings': 2,
      'steps': ['Koche {{ingredient:stable}}.'],
      'image_url': 'https://example.com/rice.jpg',
      'recipe_ingredients': [
        {
          'ingredient_id': 'rice',
          'quantity': 125,
          'unit': 'g',
          'step_key': 'stable',
          'ingredients': {'name': 'Reis'},
        },
      ],
    });
    expect(renderedRecipeSteps(row, portions: 4), ['Koche 250 g Reis.']);
    expect(row.imageUrl, restored.imageUrl);
  });
  test('Missing links are visible and unrelated numbers remain unchanged', () {
    expect(
      renderRecipeStep(
        make(100),
        '15 Minuten bei 180 Grad, {{ingredient:gone}}',
      ),
      '15 Minuten bei 180 Grad, [Zutat entfernt]',
    );
  });
}
