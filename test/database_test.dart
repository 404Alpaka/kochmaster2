import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';

import 'scroll_helpers.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/app/kochmaster_app.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/recipes/data/supabase_recipe_repository.dart';

class RetryRepository implements RecipeRepository {
  int calls = 0;
  @override
  Future<List<Recipe>> getAll() async {
    if (++calls == 1) throw Exception('offline');
    return DemoRecipeRepository().getAll();
  }
}

void main() {
  test('Postgres numeric wird korrekt eingelesen', () {
    final recipe = recipeFromRow({
      'id': 'a',
      'name': 'Test',
      'prep_minutes': 10,
      'servings': 2,
      'steps': ['Kochen'],
      'verified_allergens': ['Soja'],
      'verified_diets': ['Vegan', 'Vegetarisch'],
      'recipe_ingredients': [
        {
          'ingredient_id': 'rice',
          'quantity': 150,
          'unit': 'g',
          'ingredients': {'name': 'Reis'},
        },
      ],
    });
    expect(recipe.verifiedAllergens, {'Soja'});
    expect(recipe.verifiedDiets, {'Vegan', 'Vegetarisch'});
    final snapshot = recipeFromSnapshot(recipeSnapshot(recipe));
    expect(snapshot.verifiedAllergens, recipe.verifiedAllergens);
    expect(snapshot.verifiedDiets, recipe.verifiedDiets);
    expect(recipe.ingredients.single.quantity, 150.0);
    expect(recipe.ingredients.single.ingredientId, 'rice');
    final row = <String, dynamic>{
      'id': 'b',
      'name': 'Ungeprueft',
      'prep_minutes': 1,
      'servings': 1,
      'steps': <String>[],
      'recipe_ingredients': <dynamic>[],
    };
    expect(recipeFromRow(row).verifiedAllergens, isNull);
    row['verified_allergens'] = <String>[];
    expect(recipeFromRow(row).verifiedAllergens, isEmpty);
  });
  test(
    'Catalog and admin read recipes before optional schema migrations',
    () async {
      final requests = <Uri>[];
      final transport = MockClient((request) async {
        requests.add(request.url);
        final select = request.url.queryParameters['select']!;
        if (select.contains('step_key') ||
            select.contains('image_url') ||
            select.contains('verified_allergens')) {
          return http.Response(
            jsonEncode({'code': '42703', 'message': 'column does not exist'}),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'old',
              'name': 'Reis',
              'prep_minutes': 10,
              'servings': 2,
              'steps': ['Kochen'],
              'is_published': true,
              'deleted_at': null,
              'recipe_ingredients': [
                {
                  'ingredient_id': 'rice',
                  'quantity': 100,
                  'unit': 'g',
                  'ingredients': {'name': 'Reis'},
                },
              ],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'public-key',
        httpClient: transport,
      );
      addTearDown(client.dispose);
      final recipes = await SupabaseRecipeRepository(client).getAll();
      expect(recipes.single.name, 'Reis');
      expect(recipes.single.imageUrl, isNull);
      expect(recipes.single.verifiedAllergens, isNull);
      expect(recipes.single.ingredients.single.stepKey, isNull);
      final admin = await SupabaseAdminRecipeRepository(client).list();
      expect(admin.single.recipe.name, 'Reis');
      expect(requests.length, 2);
      expect(requests.first.queryParameters['is_published'], 'eq.true');
      expect(requests.first.queryParameters['deleted_at'], 'is.null');
    },
  );
  testWidgets('Fehler sichtbar und Wiederholen lädt Rezepte', (tester) async {
    await tester.pumpWidget(KochmasterApp(repository: RetryRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Rezepte konnten nicht geladen werden.'), findsOneWidget);
    expect(find.text('Tomaten-Spinat-Pasta'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Erneut versuchen'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Tomaten-Spinat-Pasta'));
    expect(find.text('Tomaten-Spinat-Pasta'), findsOneWidget);
    await reveal(tester, find.textContaining('Rezepte aus der Datenbank'));
    expect(find.textContaining('Rezepte aus der Datenbank'), findsOneWidget);
  });
}
