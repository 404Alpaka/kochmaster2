import 'dart:async';

class IngredientAmount {
  const IngredientAmount(
    this.ingredientId,
    this.name,
    this.quantity,
    this.unit,
  );
  final String ingredientId;
  final String name;
  final double quantity;
  final String unit;
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.minutes,
    required this.servings,
    required this.ingredients,
    required this.steps,
    this.verifiedAllergens,
    this.verifiedDiets,
  });
  final String id;
  final String name;
  final int minutes;
  final int servings;
  final List<IngredientAmount> ingredients;
  final List<String> steps;

  /// Null means the recipe has not been reviewed for planning restrictions.
  final Set<String>? verifiedAllergens;
  final Set<String>? verifiedDiets;
}

abstract interface class RecipeRepository {
  FutureOr<List<Recipe>> getAll();
}

Map<String, dynamic> recipeSnapshot(Recipe recipe) => {
  'id': recipe.id,
  'name': recipe.name,
  'minutes': recipe.minutes,
  'servings': recipe.servings,
  'steps': recipe.steps,
  'verified_allergens': recipe.verifiedAllergens?.toList(),
  'verified_diets': recipe.verifiedDiets?.toList(),
  'ingredients': [
    for (final item in recipe.ingredients)
      {
        'ingredient_id': item.ingredientId,
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
      },
  ],
};
Recipe recipeFromSnapshot(Map<String, dynamic> data) => Recipe(
  id: data['id'] as String,
  name: data['name'] as String,
  minutes: data['minutes'] as int,
  servings: data['servings'] as int,
  steps: List<String>.from(data['steps'] as List),
  verifiedAllergens: (data['verified_allergens'] as List?)
      ?.cast<String>()
      .toSet(),
  verifiedDiets: (data['verified_diets'] as List?)?.cast<String>().toSet(),
  ingredients: (data['ingredients'] as List)
      .map(
        (item) => IngredientAmount(
          item['ingredient_id'] as String,
          item['name'] as String,
          (item['quantity'] as num).toDouble(),
          item['unit'] as String,
        ),
      )
      .toList(),
);
