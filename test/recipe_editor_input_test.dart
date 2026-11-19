import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_editor_page.dart';

import 'admin_recipes_test.dart' show AdminMemoryStore;
import 'scroll_helpers.dart';

void main() {
  testWidgets('Touch outside ends input without losing recipe values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RecipeEditorPage(repository: AdminMemoryStore())),
    );
    await tester.pumpAndSettle();
    final name = find.byKey(const ValueKey('recipe-name'));
    await reveal(tester, name);
    await tester.enterText(name, 'Mein Auflauf');
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.text('Neues Rezept'), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('Mein Auflauf'), findsWidgets);
    await tester.enterText(name, 'Mein Eintopf');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('Mein Eintopf'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('All ten new categories load and save in editor', (tester) async {
    const added = {
      'stew',
      'casserole',
      'baking',
      'pasta',
      'rice',
      'potato',
      'bread',
      'cake',
      'grilling',
      'sauce',
    };
    expect(recipeCategoryLabels.length, 21);
    final store = AdminMemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeEditorPage(
          repository: store,
          existing: const AdminRecipe(
            Recipe(
              id: 'test',
              name: 'Ofengericht',
              minutes: 30,
              servings: 2,
              categories: added,
              ingredients: [IngredientAmount('rice', 'Reis', 100, 'g')],
              steps: ['Garen.'],
            ),
            published: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final key in added) {
      final chip = find.widgetWithText(FilterChip, recipeCategoryLabels[key]!);
      await reveal(tester, chip);
      expect(tester.widget<FilterChip>(chip).selected, isTrue);
    }
    final save = find.widgetWithText(FilledButton, 'Rezept speichern');
    await reveal(tester, save);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(store.payload!['categories'], unorderedEquals(added));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
