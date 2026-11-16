import 'package:supabase/supabase.dart';

import '../domain/recipe.dart';
import 'supabase_recipe_repository.dart';

class CatalogIngredient {
  const CatalogIngredient(this.id, this.name);
  final String id;
  final String name;
}

class AdminRecipe {
  const AdminRecipe(
    this.recipe, {
    required this.published,
    this.deleted = false,
  });
  final Recipe recipe;
  final bool published;
  final bool deleted;
}

abstract interface class AdminRecipeRepository {
  Future<List<AdminRecipe>> list();
  Future<List<CatalogIngredient>> ingredients();
  Future<void> save(Map<String, dynamic> recipe);
  Future<void> setDeleted(String id, bool deleted);
}

class SupabaseAdminRecipeRepository implements AdminRecipeRepository {
  SupabaseAdminRecipeRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<AdminRecipe>> list() async {
    final result = <AdminRecipe>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('recipes')
          .select(
            'id,name,prep_minutes,servings,steps,is_published,deleted_at,recipe_ingredients(ingredient_id,quantity,unit,ingredients(name))',
          )
          .order('id')
          .range(offset, offset + 199)
          .timeout(const Duration(seconds: 15));
      result.addAll(
        rows.map(
          (r) => AdminRecipe(
            recipeFromRow(r),
            published: r['is_published'] as bool,
            deleted: r['deleted_at'] != null,
          ),
        ),
      );
      if (rows.length < 200) return result;
    }
  }

  @override
  Future<List<CatalogIngredient>> ingredients() async {
    final result = <CatalogIngredient>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('ingredients')
          .select('id,name')
          .order('id')
          .range(offset, offset + 199)
          .timeout(const Duration(seconds: 15));
      result.addAll(
        rows.map(
          (r) => CatalogIngredient(r['id'] as String, r['name'] as String),
        ),
      );
      if (rows.length < 200) {
        result.sort((a, b) => a.name.compareTo(b.name));
        return result;
      }
    }
  }

  @override
  Future<void> save(Map<String, dynamic> recipe) async {
    await client
        .rpc('admin_save_recipe', params: {'p_recipe': recipe})
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> setDeleted(String id, bool deleted) async {
    await client
        .rpc(
          'admin_set_recipe_deleted',
          params: {'p_recipe_id': id, 'p_deleted': deleted},
        )
        .timeout(const Duration(seconds: 20));
  }
}
