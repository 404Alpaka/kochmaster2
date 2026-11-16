import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/shopping/domain/build_shopping_list.dart';

void main() {
  test('Zutaten werden über Rezepte hinweg addiert und Portionen skaliert', () {
    final recipes = DemoRecipeRepository().getAll();
    final items = buildShoppingList([
      PlannedMeal(recipes[0], 4),
      PlannedMeal(recipes[1], 2),
    ]);
    expect(items.singleWhere((i) => i.ingredientId == 'tomato').quantity, 800);
    expect(items.singleWhere((i) => i.ingredientId == 'pasta').quantity, 400);
    expect(buildShoppingList([]), isEmpty);
    expect(() => PlannedMeal(recipes[0], 0), throwsArgumentError);
  });
}
