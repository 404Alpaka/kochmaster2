import '../../meal_planning/domain/pantry_recipe_matcher.dart';
import '../../recipes/domain/recipe.dart';

/// Compare the complete shopping requirement once, without reserving stock.
List<PantryIngredientMatch> compareShoppingPantry(
  List<IngredientAmount> items,
  List<Map<String, dynamic>> pantry,
  DateTime today,
) {
  final date = DateTime(today.year, today.month, today.day);
  String nameKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final names = <String, Set<String>>{};
  for (final item in items) {
    names.putIfAbsent(nameKey(item.name), () => {}).add(item.ingredientId);
  }
  final valid = pantry
      .where((item) {
        final raw = item['expires'];
        if (raw == null) return true;
        final expires = DateTime.tryParse(raw as String);
        return expires != null &&
            !DateTime(expires.year, expires.month, expires.day).isBefore(date);
      })
      .map((item) {
        if (item['ingredientId'] != null) return item;
        final candidates = names[nameKey(item['name'] as String? ?? '')];
        return {
          ...item,
          'ingredientId': candidates?.length == 1 ? candidates!.single : '',
        };
      })
      .toList();
  final recipe = Recipe(
    id: 'shopping-comparison',
    name: 'Einkaufsliste',
    minutes: 0,
    servings: 1,
    ingredients: items,
    steps: const [],
  );
  return const PantryRecipeMatcher()
      .match(recipes: [recipe], pantry: valid, portions: 1)
      .single
      .matches;
}
