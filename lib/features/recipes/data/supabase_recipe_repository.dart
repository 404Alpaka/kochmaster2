import 'package:supabase/supabase.dart';

import '../domain/recipe.dart';

class SupabaseRecipeRepository implements RecipeRepository {
  SupabaseRecipeRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<Recipe>> getAll() async {
    final rows = await client
        .from('recipes')
        .select('*,recipe_ingredients(*,ingredients(name))')
        .eq('is_published', true)
        .isFilter('deleted_at', null)
        .order('name')
        .limit(100)
        .timeout(const Duration(seconds: 15));
    return rows.map(recipeFromRow).toList();
  }
}

Recipe recipeFromRow(Map<String, dynamic> row) => Recipe(
  id: row['id'] as String,
  name: row['name'] as String,
  minutes: row['prep_minutes'] as int,
  servings: row['servings'] as int,
  steps: List<String>.from(row['steps'] as List),
  imageUrl: row['image_url'] as String?,
  verifiedAllergens: (row['verified_allergens'] as List?)
      ?.cast<String>()
      .toSet(),
  verifiedDiets: (row['verified_diets'] as List?)?.cast<String>().toSet(),
  ingredients: (row['recipe_ingredients'] as List).map((value) {
    final item = value as Map<String, dynamic>;
    final ingredient = item['ingredients'] as Map<String, dynamic>;
    return IngredientAmount(
      item['ingredient_id'] as String,
      ingredient['name'] as String,
      (item['quantity'] as num).toDouble(),
      item['unit'] as String,
      stepKey: item['step_key'] as String?,
    );
  }).toList(),
);
