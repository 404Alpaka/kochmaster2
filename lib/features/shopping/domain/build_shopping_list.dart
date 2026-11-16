import '../../meal_planning/domain/meal_plan.dart';
import '../../recipes/domain/recipe.dart';

List<IngredientAmount> buildShoppingList(Iterable<PlannedMeal> meals) {
  final totals = <(String, String), IngredientAmount>{};
  for (final meal in meals) {
    for (final ingredient in meal.recipe.ingredients) {
      final key = (ingredient.ingredientId, ingredient.unit);
      final quantity =
          ingredient.quantity * meal.servings / meal.recipe.servings;
      totals[key] = IngredientAmount(
        ingredient.ingredientId,
        ingredient.name,
        (totals[key]?.quantity ?? 0) + quantity,
        ingredient.unit,
      );
    }
  }
  return totals.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

/// Purchased items remain checked only when their required quantity is unchanged.
Set<(String, String)> retainCheckedItems(
  Iterable<PlannedMeal> before,
  Iterable<PlannedMeal> after,
  Set<(String, String)> checked,
) {
  final old = {
    for (final item in buildShoppingList(before))
      (item.ingredientId, item.unit): item.quantity,
  };
  final next = {
    for (final item in buildShoppingList(after))
      (item.ingredientId, item.unit): item.quantity,
  };
  return checked
      .where(
        (key) =>
            old.containsKey(key) &&
            next.containsKey(key) &&
            (old[key]! - next[key]!).abs() < 0.000001,
      )
      .toSet();
}
