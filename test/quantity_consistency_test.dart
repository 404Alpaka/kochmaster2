import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/core/quantities.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/meal_planning/domain/pantry_recipe_matcher.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/shopping/domain/build_shopping_list.dart';
import 'package:kochmaster/features/shopping/domain/shopping_pantry.dart';

Recipe _recipe(String id, List<IngredientAmount> items, {int servings = 1}) =>
    Recipe(
      id: id,
      name: id,
      minutes: 10,
      servings: servings,
      ingredients: items,
      steps: const ['Zubereiten.'],
    );

void main() {
  test(
    'Text and structured quantities share conversions, aliases and validation',
    () {
      expect(parseQuantity(' 0,5 KG '), (500, 'g'));
      expect(parseQuantity('0.75 L'), (750, 'ml'));
      expect(parseQuantity('3 Stk.'), (3, 'Stück'));
      expect(normalizeQuantity(2, 'piece'), (2, 'Stück'));
      expect(normalizeQuantity(1, 'Packung'), isNull);
      expect(parseQuantity('2 Packungen'), (2, 'Packung'));
      expect(normalizeQuantity(double.nan, 'g'), isNull);
      expect(normalizeQuantity(double.infinity, 'ml'), isNull);
      expect(normalizeQuantity(1e308, 'kg', allowUnknown: true), isNull);
      expect(parseQuantity('-5 g'), isNull);
      expect(parseQuantity('0 kg'), isNull);
    },
  );

  test('Recipe scaling and mixed units form one total per ingredient and dimension', () {
    final first = _recipe('first', const [
      IngredientAmount('flour', 'Mehl', 0.5, 'kg'),
      IngredientAmount('milk', 'Milch', 0.25, 'l'),
      IngredientAmount('banana', 'Bananen', 1, 'Stk.'),
    ], servings: 2);
    final second = _recipe('second', const [
      IngredientAmount('flour', 'Mehl', 250, 'g'),
      IngredientAmount('milk', 'Milch', 100, 'ml'),
      IngredientAmount('banana', 'Bananen', 2, 'Stück'),
    ]);
    final items = buildShoppingList([
      PlannedMeal(first, 4),
      PlannedMeal(second, 1),
    ]);
    expect(items.singleWhere((i) => i.ingredientId == 'flour').quantity, 1250);
    expect(items.singleWhere((i) => i.ingredientId == 'milk').quantity, 600);
    expect(items.singleWhere((i) => i.ingredientId == 'banana').quantity, 4);
    expect(items.map((i) => i.unit).toSet(), {'g', 'ml', 'Stück'});
  });

  test('Opaque packages and incompatible dimensions are kept separate', () {
    final result = mergeIngredientAmounts(const [
      IngredientAmount('milk', 'Milch', 0.5, 'kg'),
      IngredientAmount('milk', 'Milch', 500, 'ml'),
      IngredientAmount('milk', 'Milch', 1, 'Packung'),
    ]);
    expect(result.map((i) => i.unit), ['g', 'ml', 'Packung']);
    expect(result.map((i) => i.quantity), [500, 500, 1]);
  });

  test('Equivalent unit swaps preserve checks; actual requirement changes reopen them', () {
    final kg = PlannedMeal(
      _recipe('kg', const [IngredientAmount('rice', 'Reis', 0.5, 'kg')]),
      1,
    );
    final grams = PlannedMeal(
      _recipe('g', const [IngredientAmount('rice', 'Reis', 500, 'g')]),
      1,
    );
    final more = PlannedMeal(
      _recipe('more', const [IngredientAmount('rice', 'Reis', 501, 'g')]),
      1,
    );
    expect(retainCheckedItems([kg], [grams], {('rice', 'kg')}), {
      ('rice', 'g'),
    });
    expect(retainCheckedItems([kg], [grams], {('rice', 'g')}), {('rice', 'g')});
    expect(retainCheckedItems([kg], [more], {('rice', 'g')}), isEmpty);
    expect(retainCheckedItems([kg], [], {('rice', 'g')}), isEmpty);
  });

  test('Legacy source-unit checks do not mark an additional unchecked unit as bought', () {
    final meals = [
      PlannedMeal(
        _recipe('mixed', const [
          IngredientAmount('rice', 'Reis', 1, 'kg'),
          IngredientAmount('rice', 'Reis', 500, 'g'),
        ]),
        1,
      ),
    ];
    expect(normalizeCheckedItems(meals, {('rice', 'kg')}), isEmpty);
    expect(normalizeCheckedItems(meals, {('rice', 'kg'), ('rice', 'g')}), {
      ('rice', 'g'),
    });
    expect(normalizeCheckedItems(meals, {('rice', 'g')}), {('rice', 'g')});
    final pieces = [
      PlannedMeal(
        _recipe('pieces', const [
          IngredientAmount('banana', 'Bananen', 2, 'Stk.'),
          IngredientAmount('banana', 'Bananen', 3, 'Stück'),
        ]),
        1,
      ),
    ];
    expect(normalizeCheckedItems(pieces, {('banana', 'Stk.')}), isEmpty);
    expect(
      normalizeCheckedItems(pieces, {('banana', 'Stk.'), ('banana', 'Stück')}),
      {('banana', 'Stück')},
    );
  });

  test('Checks for unchanged extra items survive plan edits; added quantities reopen them', () {
    final first = PlannedMeal(
      _recipe('a', const [IngredientAmount('rice', 'Reis', 100, 'g')]),
      1,
    );
    final second = PlannedMeal(
      _recipe('b', const [IngredientAmount('milk', 'Milch', 1, 'l')]),
      1,
    );
    const extra = [IngredientAmount('banana', 'Bananen', 3, 'stk')];
    expect(
      retainCheckedItems([first], [first, second], {
        ('banana', 'Stück'),
        ('rice', 'g'),
      }, additionalItems: extra),
      {('banana', 'Stück'), ('rice', 'g')},
    );
    expect(
      retainCheckedQuantities(
        extra,
        const [IngredientAmount('banana', 'Bananen', 4, 'Stück')],
        {('banana', 'Stück')},
      ),
      isEmpty,
    );
  });

  test('Repeated ingredient rows share one stock requirement rather than counting the stock twice', () {
    final recipe = _recipe('combined', const [
      IngredientAmount('rice', 'Reis', 0.4, 'kg'),
      IngredientAmount('rice', 'Reis', 400, 'g'),
    ]);
    const stock = [
      {'ingredientId': 'rice', 'amount': '0,5 kg'},
    ];
    final match = const PantryRecipeMatcher()
        .match(recipes: [recipe], pantry: stock, portions: 1)
        .single;
    expect(match.matches, hasLength(1));
    expect(match.immediatelyCookable, isFalse);
    expect(match.matches.single.requiredQuantity, 800);
    expect(match.matches.single.availableQuantity, 500);
    expect(match.matches.single.missingQuantity, 300);
    final shopping = compareShoppingPantry(
      buildShoppingList([PlannedMeal(recipe, 1)]),
      stock,
      DateTime(2026, 11, 25),
    ).single;
    expect(shopping.requiredQuantity, match.matches.single.requiredQuantity);
    expect(shopping.missingQuantity, match.matches.single.missingQuantity);
  });

  test(
    'Ambiguous ingredient names cannot assign stock to one arbitrary ID',
    () {
      final recipe = _recipe('ambiguous', const [
        IngredientAmount('a', 'Milch', 100, 'ml'),
        IngredientAmount('b', 'Milch', 200, 'ml'),
      ]);
      final match = const PantryRecipeMatcher()
          .match(
            recipes: [recipe],
            pantry: const [
              {'name': 'Milch', 'amount': '1 l'},
            ],
            portions: 1,
          )
          .single;
      expect(
        match.matches.every((item) => item.availableQuantity == 0),
        isTrue,
      );
    },
  );
}
