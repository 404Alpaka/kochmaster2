import '../../../core/quantities.dart';
import 'recipe.dart';

List<IngredientAmount> mergeIngredientAmounts(
  Iterable<IngredientAmount> items,
) {
  final totals = <(String, String), IngredientAmount>{};
  for (final item in items) {
    final normalized = normalizeQuantity(
      item.quantity,
      item.unit,
      allowUnknown: true,
    );
    if (normalized == null) continue;
    final key = (item.ingredientId, normalized.$2);
    totals[key] = IngredientAmount(
      item.ingredientId,
      item.name,
      (totals[key]?.quantity ?? 0) + normalized.$1,
      normalized.$2,
    );
  }
  return totals.values.toList();
}
