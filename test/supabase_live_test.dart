import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/core/config/app_config.dart';
import 'package:kochmaster/features/recipes/data/supabase_recipe_repository.dart';

void main() {
  test(
    'Live: öffentliche API liefert vollständige Rezepte und Zutaten',
    () async {
      final client = SupabaseClient(AppConfig.url, AppConfig.publishableKey);
      try {
        final recipes = await SupabaseRecipeRepository(client).getAll();
        expect(recipes.length, greaterThanOrEqualTo(20));
        expect(recipes.map((r) => r.id).toSet().length, recipes.length);
        for (final recipe in recipes) {
          expect(recipe.name, isNotEmpty);
          expect(recipe.ingredients, isNotEmpty);
          expect(recipe.steps, isNotEmpty);
          expect(recipe.servings, greaterThan(0));
          for (final ingredient in recipe.ingredients) {
            expect(ingredient.name, isNotEmpty);
            expect(ingredient.quantity, greaterThan(0));
          }
        }
      } finally {
        await client.dispose();
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_TESTS'),
  );
}
