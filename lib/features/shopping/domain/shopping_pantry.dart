import '../../meal_planning/domain/pantry_recipe_matcher.dart';
import '../../recipes/domain/recipe.dart';
import '../../../core/quantities.dart';

class PurchasedShoppingAmount {
  const PurchasedShoppingAmount({
    required this.item,
    required this.quantity,
    required this.location,
  });

  final IngredientAmount item;
  final double quantity;
  final String location;
}

List<Map<String, dynamic>> addPurchasedShoppingAmountsToPantry(
  List<Map<String, dynamic>> pantry,
  Iterable<PurchasedShoppingAmount> purchases,
) {
  final result = pantry
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  for (final purchase in purchases) {
    final normalized = normalizeQuantity(
      purchase.quantity,
      purchase.item.unit,
      allowUnknown: true,
    );
    if (normalized == null) {
      throw ArgumentError.value(
        purchase.quantity,
        'quantity',
        'Purchased amount must be finite and positive.',
      );
    }

    final isCustom = purchase.item.ingredientId.startsWith('manual:');
    final index = result.indexWhere((item) {
      if (item['location'] != purchase.location || item['expires'] != null) {
        return false;
      }
      final sameItem = isCustom
          ? item['ingredientId'] == null &&
                item['name'] == purchase.item.name
          : item['ingredientId'] == purchase.item.ingredientId;
      if (!sameItem) return false;
      final existing = parseQuantity(item['amount'] as String?);
      return existing != null && existing.$2 == normalized.$2;
    });

    final amount = _shoppingQuantityLabel(normalized.$1, normalized.$2);
    if (index >= 0) {
      final existing = parseQuantity(result[index]['amount'] as String?)!;
      result[index]['amount'] = _shoppingQuantityLabel(
        existing.$1 + normalized.$1,
        normalized.$2,
      );
    } else {
      result.add({
        if (!isCustom) 'ingredientId': purchase.item.ingredientId,
        'name': purchase.item.name,
        'amount': amount,
        'location': purchase.location,
        'expires': null,
      });
    }
  }
  return result;
}

String _shoppingQuantityLabel(double quantity, String unit) {
  final formatted = quantity
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
  return '$formatted $unit'.trim();
}

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
