import 'package:supabase/supabase.dart';

import '../domain/recipe.dart';

class SupabaseRecipeRepository implements RecipeRepository {
  SupabaseRecipeRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<Recipe>> getAll() async {
    final rows = await client
        .from('recipes')
        .select(
          'id,name,prep_minutes,servings,steps,recipe_ingredients(ingredient_id,quantity,unit,ingredients(name))',
        )
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
  ingredients: (row['recipe_ingredients'] as List).map((value) {
    final item = value as Map<String, dynamic>;
    final ingredient = item['ingredients'] as Map<String, dynamic>;
    return IngredientAmount(
      item['ingredient_id'] as String,
      ingredient['name'] as String,
      (item['quantity'] as num).toDouble(),
      item['unit'] as String,
    );
  }).toList(),
);
