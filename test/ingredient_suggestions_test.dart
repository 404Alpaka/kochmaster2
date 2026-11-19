import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/features/recipes/data/ingredient_suggestions.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_editor_page.dart';

import 'ingredient_search_test.dart' show SearchStore;
import 'scroll_helpers.dart';

void main() {
  test(
    'Suggestions match prefixes, umlauts and spelling errors, capped at five',
    () async {
      final catalog = await SearchStore().ingredients();
      expect(suggestIngredients(catalog, ' TOM ').first.id, 'tomato');
      expect(suggestIngredients(catalog, 'Tomtaen').first.id, 'tomato');
      expect(suggestIngredients(catalog, 'Ries').first.id, 'rice');
      expect(suggestIngredients(catalog, 'kaese').first.id, 'cheese');
      expect(suggestIngredients(catalog, 'xyz'), isEmpty);
      expect(suggestIngredients(catalog, 't'), isEmpty);
      expect(
        suggestIngredients([...catalog, ...catalog, ...catalog], 'to').length,
        lessThanOrEqualTo(5),
      );
    },
  );

  testWidgets(
    'Typing an ingredient offers existing choices and saves selected ID',
    (tester) async {
      final store = SearchStore();
      await tester.pumpWidget(
        MaterialApp(home: RecipeEditorPage(repository: store)),
      );
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('recipe-name'));
      await reveal(tester, name);
      await tester.enterText(name, 'Tomatengericht');
      final ingredient = find.byKey(const ValueKey('ingredient-name-0'));
      await reveal(tester, ingredient);
      await tester.enterText(ingredient, 'Tomtaen');
      await tester.pumpAndSettle();
      final suggestion = find.byKey(
        const ValueKey('ingredient-suggestion-0-tomato'),
      );
      expect(suggestion, findsOneWidget);
      await tester.ensureVisible(suggestion);
      await tester.pumpAndSettle();
      await tester.tap(suggestion);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ingredient-name-0')), findsNothing);
      final amount = find.byKey(const ValueKey('ingredient-amount-0'));
      await reveal(tester, amount);
      await tester.enterText(amount, '150');
      final steps = find.byKey(const ValueKey('recipe-steps'));
      await reveal(tester, steps);
      await tester.enterText(steps, 'Tomaten schneiden.');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rezept speichern'));
      await tester.pumpAndSettle();
      final saved = (store.payload!['ingredients'] as List).single as Map;
      expect(saved['ingredient_id'], 'tomato');
      expect(saved['name'], 'Tomaten');
      expect(saved['quantity'], 150);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
