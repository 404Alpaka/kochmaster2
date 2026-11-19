import 'dart:async';

class IngredientAmount {
  const IngredientAmount(
    this.ingredientId,
    this.name,
    this.quantity,
    this.unit, {
    this.stepKey,
  });
  final String ingredientId;
  final String name;
  final double quantity;
  final String unit;
  final String? stepKey;
  String get referenceKey =>
      stepKey ?? Uri.encodeComponent('$ingredientId|$unit');
}

const planningAllergens = [
  'Milch',
  'Eier',
  'Erdnüsse',
  'Schalenfrüchte',
  'Gluten',
  'Soja',
];
const planningDiets = ['Vegetarisch', 'Vegan'];
const recipeCategoryLabels = {
  'meat': 'Fleisch',
  'fish': 'Fisch',
  'vegetarian': 'Vegetarisch',
  'vegan': 'Vegan',
  'starter': 'Vorspeisen',
  'main': 'Hauptgerichte',
  'soup': 'Suppen',
  'salad': 'Salate',
  'dessert': 'Desserts',
  'breakfast': 'Frühstück',
  'snack': 'Snacks',
  'stew': 'Eintöpfe',
  'casserole': 'Aufläufe',
  'baking': 'Backen',
  'pasta': 'Pasta',
  'rice': 'Reisgerichte',
  'potato': 'Kartoffelgerichte',
  'bread': 'Brot & Brötchen',
  'cake': 'Kuchen & Gebäck',
  'grilling': 'Grillen',
  'sauce': 'Soßen & Dips',
};

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.minutes,
    required this.servings,
    required this.ingredients,
    required this.steps,
    this.imageUrl,
    this.verifiedAllergens,
    this.verifiedDiets,
    this.categories = const {},
    this.favoriteCount = 0,
  });
  final String id;
  final String name;
  final String? imageUrl;
  final int minutes;
  final int servings;
  final List<IngredientAmount> ingredients;
  final List<String> steps;

  /// Null means the recipe has not been reviewed for planning restrictions.
  final Set<String>? verifiedAllergens;
  final Set<String>? verifiedDiets;
  final Set<String> categories;
  final int favoriteCount;
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
  'image_url': recipe.imageUrl,
  'verified_allergens': recipe.verifiedAllergens?.toList(),
  'verified_diets': recipe.verifiedDiets?.toList(),
  'categories': recipe.categories.toList(),
  'ingredients': [
    for (final item in recipe.ingredients)
      {
        'ingredient_id': item.ingredientId,
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'step_key': item.stepKey,
      },
  ],
};
Recipe recipeFromSnapshot(Map<String, dynamic> data) => Recipe(
  id: data['id'] as String,
  name: data['name'] as String,
  minutes: data['minutes'] as int,
  servings: data['servings'] as int,
  steps: List<String>.from(data['steps'] as List),
  imageUrl: data['image_url'] as String?,
  verifiedAllergens: (data['verified_allergens'] as List?)
      ?.cast<String>()
      .toSet(),
  verifiedDiets: (data['verified_diets'] as List?)?.cast<String>().toSet(),
  categories: (data['categories'] as List?)?.cast<String>().toSet() ?? {},
  ingredients: (data['ingredients'] as List)
      .map(
        (item) => IngredientAmount(
          item['ingredient_id'] as String,
          item['name'] as String,
          (item['quantity'] as num).toDouble(),
          item['unit'] as String,
          stepKey: item['step_key'] as String?,
        ),
      )
      .toList(),
);

/// Unknown or free-form restrictions never imply a reviewed match.
bool matchesVerifiedRestrictions(
  Recipe recipe,
  String diet,
  Set<String> exclusions,
) {
  if (diet != 'Ohne Einschränkung' &&
      !(recipe.verifiedDiets?.contains(diet) ?? false)) {
    return false;
  }
  if (exclusions.isEmpty) return true;
  return planningAllergens.toSet().containsAll(exclusions) &&
      recipe.verifiedAllergens != null &&
      recipe.verifiedAllergens!.intersection(exclusions).isEmpty;
}

String ingredientToken(String key) => '{{ingredient:$key}}';
String ingredientText(IngredientAmount item, double factor) =>
    '${(item.quantity * factor).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',')} ${item.unit} ${item.name}';
String renderRecipeStep(Recipe recipe, String step, {int? portions}) =>
    step.replaceAllMapped(RegExp(r'\{\{ingredient:([^}]+)\}\}'), (match) {
      for (final item in recipe.ingredients) {
        if (item.referenceKey == match[1]) {
          return ingredientText(
            item,
            (portions ?? recipe.servings) / recipe.servings,
          );
        }
      }
      return '[Zutat entfernt]';
    });
List<String> renderedRecipeSteps(Recipe recipe, {int? portions}) => recipe.steps
    .map((s) => renderRecipeStep(recipe, s, portions: portions))
    .toList();
