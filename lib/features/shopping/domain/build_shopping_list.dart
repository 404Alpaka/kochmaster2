import '../../meal_planning/domain/meal_plan.dart';
import '../../recipes/domain/recipe.dart';
import '../../../core/quantities.dart';
import '../../recipes/domain/ingredient_amounts.dart';

export '../../recipes/domain/ingredient_amounts.dart'
    show mergeIngredientAmounts;

Iterable<IngredientAmount> _plannedIngredients(
  Iterable<PlannedMeal> meals,
) sync* {
  for (final meal in meals) {
    if (meal.preparedMealId != null) continue;
    for (final item in meal.recipe.ingredients) {
      yield IngredientAmount(
        item.ingredientId,
        item.name,
        item.quantity * meal.servings / meal.recipe.servings,
        item.unit,
      );
    }
  }
}

List<IngredientAmount> buildShoppingList(
  Iterable<PlannedMeal> meals, {
  Iterable<IngredientAmount> additionalItems = const [],
}) =>
    mergeIngredientAmounts([..._plannedIngredients(meals), ...additionalItems])
      ..sort((a, b) => a.name.compareTo(b.name));

Set<(String, String)> _normalizeCheckedQuantities(
  Iterable<IngredientAmount> items,
  Set<(String, String)> checked,
) {
  final rawChecks = {
    for (final key in checked) (key.$1, key.$2.trim().toLowerCase()),
  };
  final canonicalChecks = {
    for (final key in checked) (key.$1, canonicalQuantityUnit(key.$2)),
  };
  final contributors = <(String, String), Set<(String, String)>>{};
  for (final item in items) {
    final normalized = normalizeQuantity(
      item.quantity,
      item.unit,
      allowUnknown: true,
    );
    if (normalized == null) continue;
    final key = (item.ingredientId, normalized.$2);
    contributors.putIfAbsent(key, () => {}).add((
      item.ingredientId,
      item.unit.trim().toLowerCase(),
    ));
  }
  return {
    for (final entry in contributors.entries)
      // Current clients check the combined base-unit row. Older source-unit
      // checks can migrate only when every contributing source row was checked.
      if (rawChecks.contains((entry.key.$1, entry.key.$2.toLowerCase())) ||
          (entry.value.length == 1 && canonicalChecks.contains(entry.key)) ||
          entry.value.every(rawChecks.contains))
        entry.key,
  };
}

Set<(String, String)> normalizeCheckedItems(
  Iterable<PlannedMeal> meals,
  Set<(String, String)> checked, {
  Iterable<IngredientAmount> additionalItems = const [],
}) => _normalizeCheckedQuantities([
  ..._plannedIngredients(meals),
  ...additionalItems,
], checked);

Set<(String, String)> retainCheckedQuantities(
  Iterable<IngredientAmount> before,
  Iterable<IngredientAmount> after,
  Set<(String, String)> checked,
) {
  final old = {
    for (final item in mergeIngredientAmounts(before))
      (item.ingredientId, item.unit): item.quantity,
  };
  final next = {
    for (final item in mergeIngredientAmounts(after))
      (item.ingredientId, item.unit): item.quantity,
  };
  return _normalizeCheckedQuantities(before, checked)
      .where(
        (key) =>
            old.containsKey(key) &&
            next.containsKey(key) &&
            sameQuantity(old[key]!, next[key]!),
      )
      .toSet();
}

/// Purchased items remain checked only when their required quantity is unchanged.
Set<(String, String)> retainCheckedItems(
  Iterable<PlannedMeal> before,
  Iterable<PlannedMeal> after,
  Set<(String, String)> checked, {
  Iterable<IngredientAmount> additionalItems = const [],
}) => retainCheckedQuantities(
  [..._plannedIngredients(before), ...additionalItems],
  [..._plannedIngredients(after), ...additionalItems],
  checked,
);
