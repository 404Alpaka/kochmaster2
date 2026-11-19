import '../../recipes/domain/recipe.dart';

/// Quantities are comparable only within the same dimension. No density or
/// package-size assumptions are made for cans, bunches or free-text units.
(double, String)? planningQuantity(double quantity, String unit) {
  if (!quantity.isFinite || quantity <= 0) return null;
  final normalized = unit.trim().toLowerCase();
  final converted = switch (normalized) {
    'kg' => (quantity * 1000, 'g'),
    'g' => (quantity, 'g'),
    'l' => (quantity * 1000, 'ml'),
    'ml' => (quantity, 'ml'),
    'stück' || 'stueck' || 'stk' || 'stk.' => (quantity, 'piece'),
    _ => null,
  };
  return converted == null || !converted.$1.isFinite ? null : converted;
}

class PlanningStock {
  const PlanningStock({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    this.expires,
  });
  final String ingredientId, unit;
  final double quantity;
  final DateTime? expires;
}

class PlanningResources {
  const PlanningResources({
    this.stock = const [],
    this.costPerServing = const {},
    this.budget,
    this.costClass,
  });
  final List<PlanningStock> stock;

  /// Explicit user estimates; never live product prices.
  final Map<String, double> costPerServing;
  final double? budget;

  /// Optional ordinal preference: low, medium or high.
  final String? costClass;

  bool get hasStock =>
      stock.any((s) => planningQuantity(s.quantity, s.unit) != null);
  bool get hasBudget =>
      (budget != null && budget!.isFinite && budget! > 0) ||
      costRank(costClass) != null;
  static int? costRank(String? value) => switch (value?.trim().toLowerCase()) {
    'low' || 'günstig' => 0,
    'medium' || 'mittel' => 1,
    'high' || 'hoch' => 2,
    _ => null,
  };

  double? estimatedCost(Recipe recipe, int servings) {
    final price = costPerServing[recipe.id];
    if (price == null || !price.isFinite || price < 0 || servings <= 0) {
      return null;
    }
    final total = price * servings;
    return total.isFinite ? total : null;
  }

  double budgetScore(Recipe recipe, int servings, int plannedServings) {
    final price = estimatedCost(recipe, servings);
    if (price != null &&
        budget != null &&
        budget!.isFinite &&
        budget! > 0 &&
        plannedServings > 0) {
      final allowance = budget! * servings / plannedServings;
      return price <= allowance
          ? 75 + 25 * (1 - price / allowance)
          : (75 - 75 * (price / allowance - 1)).clamp(0, 75);
    }
    final target = costRank(costClass), actual = costRank(recipe.costClass);
    if (target == null || actual == null) return 50;
    return actual <= target ? 85 : (85 - 35 * (actual - target)).toDouble();
  }

  /// First-expiring lots are allocated once, in meal-date order. This is a
  /// hypothetical allocation only; generating a proposal never changes stock.
  Map<int, double> pantryScores(
    Map<int, Recipe> meals,
    Map<int, (DateTime, int)> schedule,
  ) {
    final lots =
        stock
            .where((s) => planningQuantity(s.quantity, s.unit) != null)
            .toList()
          ..sort((a, b) {
            if (a.expires == null) return b.expires == null ? 0 : 1;
            if (b.expires == null) return -1;
            return a.expires!.compareTo(b.expires!);
          });
    final remaining = [
      for (final lot in lots) planningQuantity(lot.quantity, lot.unit)!.$1,
    ];
    final order = meals.keys.toList()
      ..sort((a, b) {
        final date = schedule[a]!.$1.compareTo(schedule[b]!.$1);
        return date == 0 ? a.compareTo(b) : date;
      });
    final scores = <int, double>{};
    for (final day in order) {
      final recipe = meals[day]!;
      final (date, servings) = schedule[day]!;
      final needed = <(String, String), double>{};
      for (final ingredient in recipe.ingredients) {
        final parsed = planningQuantity(
          ingredient.quantity * servings / recipe.servings,
          ingredient.unit,
        );
        if (parsed != null) {
          final key = (ingredient.ingredientId, parsed.$2);
          needed[key] = (needed[key] ?? 0) + parsed.$1;
        }
      }
      var covered = 0.0;
      for (final ingredient in needed.entries) {
        var wanted = ingredient.value;
        var used = 0.0;
        for (var i = 0; i < lots.length && wanted > 0; i++) {
          final lot = lots[i];
          if (lot.ingredientId != ingredient.key.$1 ||
              planningQuantity(lot.quantity, lot.unit)!.$2 != ingredient.key.$2) {
            continue;
          }
          if (lot.expires != null &&
              DateTime.utc(
                lot.expires!.year,
                lot.expires!.month,
                lot.expires!.day,
              ).isBefore(DateTime.utc(date.year, date.month, date.day))) {
            continue;
          }
          final amount = remaining[i] < wanted ? remaining[i] : wanted;
          remaining[i] -= amount;
          wanted -= amount;
          used += amount;
        }
        covered += used / ingredient.value;
      }
      // No usable metadata is neutral; a known usable stock match adds benefit.
      scores[day] = needed.isEmpty ? 50 : 50 + 50 * covered / needed.length;
    }
    return scores;
  }
}
