import '../../recipes/domain/recipe.dart';
import 'planning_resources.dart';

enum PantryIngredientState { full, partial, missing }

class PantryIngredientMatch {
  const PantryIngredientMatch({
    required this.ingredient,
    required this.requiredQuantity,
    required this.availableQuantity,
    required this.unit,
    required this.state,
  });

  final IngredientAmount ingredient;
  final double requiredQuantity;
  final double availableQuantity;
  final String unit;
  final PantryIngredientState state;

  double get missingQuantity => ((requiredQuantity - availableQuantity).clamp(
    0,
    double.infinity,
  )).toDouble();
}

class PantryRecipeMatch {
  const PantryRecipeMatch({
    required this.recipe,
    required this.portions,
    required this.matches,
  });

  final Recipe recipe;
  final int portions;
  final List<PantryIngredientMatch> matches;

  int get requiredCount => matches.length;
  int get availableCount =>
      matches.where((m) => m.state != PantryIngredientState.missing).length;
  int get missingCount =>
      matches.where((m) => m.state != PantryIngredientState.full).length;
  int get partialCount =>
      matches.where((m) => m.state == PantryIngredientState.partial).length;
  int get fullyMissingCount =>
      matches.where((m) => m.state == PantryIngredientState.missing).length;
  int get percentage => requiredCount == 0
      ? 0
      : ((availableCount * 100) / requiredCount).round().clamp(0, 100);
  bool get immediatelyCookable =>
      matches.every((m) => m.state == PantryIngredientState.full);

  PantryRecipeGroup get group {
    if (immediatelyCookable) return PantryRecipeGroup.cookable;
    if (missingCount <= 2) return PantryRecipeGroup.nearly;
    return PantryRecipeGroup.other;
  }
}

enum PantryRecipeGroup { cookable, nearly, other }

class PantryRecipeMatcher {
  const PantryRecipeMatcher();

  List<PantryRecipeMatch> match({
    required List<Recipe> recipes,
    required List<Map<String, dynamic>> pantry,
    required int portions,
  }) {
    final stock = <String, Map<String, double>>{};
    final names = <String, String>{
      for (final recipe in recipes)
        for (final ingredient in recipe.ingredients)
          _normalizeName(ingredient.name): ingredient.ingredientId,
    };

    for (final item in pantry) {
      var id = item['ingredientId'] as String?;
      id ??= names[_normalizeName(item['name'] as String? ?? '')];
      if (id == null) continue;
      final parsed = _parsePantryAmount(item['amount'] as String?);
      if (parsed == null) continue;
      final converted = planningQuantity(parsed.$1, parsed.$2);
      if (converted == null) continue;
      final units = stock.putIfAbsent(id, () => <String, double>{});
      units[converted.$2] = (units[converted.$2] ?? 0) + converted.$1;
    }

    final results = <PantryRecipeMatch>[];
    for (final recipe in recipes) {
      final matches = <PantryIngredientMatch>[];
      for (final ingredient in recipe.ingredients) {
        final scaled = planningQuantity(
          ingredient.quantity * portions / recipe.servings,
          ingredient.unit,
        );
        if (scaled == null) {
          matches.add(
            PantryIngredientMatch(
              ingredient: ingredient,
              requiredQuantity:
                  ingredient.quantity * portions / recipe.servings,
              availableQuantity: 0,
              unit: ingredient.unit,
              state: PantryIngredientState.missing,
            ),
          );
          continue;
        }
        final available = stock[ingredient.ingredientId]?[scaled.$2] ?? 0;
        final state = available >= scaled.$1
            ? PantryIngredientState.full
            : available > 0
            ? PantryIngredientState.partial
            : PantryIngredientState.missing;
        matches.add(
          PantryIngredientMatch(
            ingredient: ingredient,
            requiredQuantity: scaled.$1,
            availableQuantity: available,
            unit: scaled.$2,
            state: state,
          ),
        );
      }
      results.add(
        PantryRecipeMatch(recipe: recipe, portions: portions, matches: matches),
      );
    }

    results.sort((a, b) {
      final group = a.group.index.compareTo(b.group.index);
      if (group != 0) return group;
      final match = b.percentage.compareTo(a.percentage);
      return match != 0 ? match : a.recipe.name.compareTo(b.recipe.name);
    });
    return results;
  }

  String _normalizeName(String name) => name
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  (double, String)? _parsePantryAmount(String? amount) {
    final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(.*?)\s*$')
        .firstMatch(amount ?? '');
    if (match == null) return null;
    final quantity = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (quantity == null) return null;
    final rawUnit = match.group(2)!.trim();
    final unit = switch (rawUnit.toLowerCase()) {
      'kg' => 'kg',
      'g' => 'g',
      'l' => 'l',
      'ml' => 'ml',
      'stück' || 'stueck' || 'stk' || 'stk.' => 'Stück',
      _ => rawUnit,
    };
    return (quantity, unit);
  }
}
