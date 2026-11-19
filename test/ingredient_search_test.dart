import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/presentation/ingredient_search_sheet.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_editor_page.dart';

import 'admin_recipes_test.dart' show AdminMemoryStore;
import 'scroll_helpers.dart';

class SearchStore extends AdminMemoryStore {
  @override
  Future<List<CatalogIngredient>> ingredients() async => const [
    CatalogIngredient('rice', 'Reis'),
    CatalogIngredient('tomato', 'Tomaten'),
    CatalogIngredient('cheese', 'Käse'),
  ];
}

void main() {
  testWidgets('Search existing ingredient, select and save its catalog ID', (
    tester,
  ) async {
    final store = SearchStore();
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeEditorPage(
          repository: store,
          existing: const AdminRecipe(
            Recipe(
              id: 'r',
              name: 'Reisgericht',
              minutes: 20,
              servings: 2,
              ingredients: [IngredientAmount('rice', 'Reis', 100, 'g')],
              steps: ['Garen.'],
            ),
            published: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('ingredient-picker-0'));
    await reveal(tester, picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ingredient-search')),
      '  TOM  ',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('ingredient-result-tomato')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ingredient-result-rice')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ingredient-result-tomato')));
    await tester.pumpAndSettle();
    expect(find.byType(IngredientSearchSheet), findsNothing);
    final save = find.widgetWithText(FilledButton, 'Rezept speichern');
    await reveal(tester, save);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final ingredient = (store.payload!['ingredients'] as List).single as Map;
    expect(ingredient['ingredient_id'], 'tomato');
    expect(ingredient['quantity'], 100);
    expect(ingredient['name'], 'Tomaten');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Search supports umlauts, empty results and creating a new ingredient',
    (tester) async {
      CatalogIngredient? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<CatalogIngredient>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => SizedBox(
                      height: 450,
                      child: IngredientSearchSheet(
                        catalog: const [CatalogIngredient('cheese', 'Käse')],
                      ),
                    ),
                  );
                },
                child: const Text('Suchen'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Suchen'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('ingredient-search'));
      await tester.enterText(search, 'kaese');
      await tester.pumpAndSettle();
      expect(find.text('Käse'), findsOneWidget);
      expect(find.textContaining('neu anlegen'), findsNothing);
      await tester.enterText(search, 'Pastinake');
      await tester.pumpAndSettle();
      expect(find.text('Keine passende Zutat gefunden.'), findsOneWidget);
      await tester.tap(find.text('„Pastinake“ neu anlegen'));
      await tester.pumpAndSettle();
      expect(result!.name, 'Pastinake');
      expect(result!.id, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
