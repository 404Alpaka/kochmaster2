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
    final counts = <String, int>{};
    try {
      final values = await client
          .rpc('recipe_popularity')
          .timeout(const Duration(seconds: 15));
      for (final value in values as List) {
        counts[value['recipe_id'] as String] = (value['favorite_count'] as num)
            .toInt();
      }
    } on PostgrestException catch (error) {
      if (!['PGRST202', '42883'].contains(error.code)) rethrow;
    }
    return rows
        .map((row) => recipeFromRow(row, favoriteCount: counts[row['id']] ?? 0))
        .toList();
  }
}

Recipe recipeFromRow(Map<String, dynamic> row, {int favoriteCount = 0}) =>
    Recipe(
      primarySide: row['primary_side'] as String?,
      dishType: row['dish_type'] as String?,
      mainIngredient: row['main_ingredient'] as String?,
      activeMinutes: row['active_minutes'] as int?,
      preparationMethod: row['preparation_method'] as String?,
      flavors: (row['flavors'] as List?)?.cast<String>().toSet() ?? {},
      costClass: row['cost_class'] as String?,
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
      categories: (row['categories'] as List?)?.cast<String>().toSet() ?? {},
      favoriteCount: favoriteCount,
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
