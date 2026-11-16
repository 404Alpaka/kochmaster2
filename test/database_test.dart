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
      'recipe_ingredients': [
        {
          'ingredient_id': 'rice',
          'quantity': 150,
          'unit': 'g',
          'ingredients': {'name': 'Reis'},
        },
      ],
    });
    expect(recipe.ingredients.single.quantity, 150.0);
    expect(recipe.ingredients.single.ingredientId, 'rice');
  });
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
