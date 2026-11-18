import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';

Recipe recipe(Set<String>? allergens, Set<String>? diets) => Recipe(
  id: 'r',
  name: 'Reis',
  minutes: 10,
  servings: 2,
  ingredients: [],
  steps: [],
  verifiedAllergens: allergens,
  verifiedDiets: diets,
);
void main() {
  test('Unknown data never releases restricted recipes', () {
    expect(
      matchesVerifiedRestrictions(recipe(null, null), 'Vegan', {}),
      isFalse,
    );
    expect(
      matchesVerifiedRestrictions(recipe(null, null), 'Ohne Einschränkung', {
        'Soja',
      }),
      isFalse,
    );
    expect(
      matchesVerifiedRestrictions(recipe(null, null), 'Ohne Einschränkung', {}),
      isTrue,
    );
  });
  test(
    'Reviewed empty allergens, contained allergens and free text are distinct',
    () {
      expect(
        matchesVerifiedRestrictions(
          recipe({}, {'Vegan', 'Vegetarisch'}),
          'Vegan',
          {'Soja'},
        ),
        isTrue,
      );
      expect(
        matchesVerifiedRestrictions(recipe({'Soja'}, {'Vegan'}), 'Vegan', {
          'Soja',
        }),
        isFalse,
      );
      expect(
        matchesVerifiedRestrictions(recipe({}, {'Vegetarisch'}), 'Vegan', {}),
        isFalse,
      );
      expect(
        matchesVerifiedRestrictions(recipe({}, {}), 'Ohne Einschränkung', {
          'Sellerie',
        }),
        isFalse,
      );
    },
  );
}
