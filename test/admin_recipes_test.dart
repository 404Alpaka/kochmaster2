import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/presentation/admin_recipes_page.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_editor_page.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';

class AdminMemoryStore implements AdminRecipeRepository {
  final items = <AdminRecipe>[];
  Map<String, dynamic>? payload;
  bool fail = false;
  bool ingredientLoadFails = false;
  @override
  Future<List<AdminRecipe>> list() async => items.toList();
  @override
  Future<List<CatalogIngredient>> ingredients() async {
    if (ingredientLoadFails) {
      throw StateError('offline');
    }
    return [const CatalogIngredient('rice', 'Reis')];
  }

  @override
  Future<void> save(Map<String, dynamic> recipe) async {
    if (fail) throw StateError('offline');
    payload = recipe;
  }

  @override
  Future<void> setDeleted(String id, bool deleted) async {
    final index = items.indexWhere((r) => r.recipe.id == id);
    items[index] = AdminRecipe(
      items[index].recipe,
      published: items[index].published,
      deleted: deleted,
    );
  }
}

void main() {
  test(
    'Gespeicherte Wochenpläne bleiben nach Entfernen eines Rezepts lesbar',
    () {
      final recipe = DemoRecipeRepository().getAll().first;
      final encoded = WeeklyPlan(meals: {0: PlannedMeal(recipe, 4)}).toJson();
      final restored = WeeklyPlan.fromJson(encoded, []);
      expect(restored.meals[0]!.recipe.name, recipe.name);
      expect(
        restored.meals[0]!.recipe.ingredients.first.quantity,
        recipe.ingredients.first.quantity,
      );
      expect(restored.meals[0]!.servings, 4);
      final legacy = WeeklyPlan.fromJson(
        {
          'meals': [
            {'day': 0, 'recipe_id': recipe.id, 'servings': 2},
          ],
          'checked': [],
        },
        [recipe],
      );
      expect(legacy.meals[0]!.recipe.id, recipe.id);
    },
  );
  testWidgets('Rezeptformular validiert und speichert alle Felder', (
    tester,
  ) async {
    final store = AdminMemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => RecipeEditorPage(repository: store),
              ),
            ),
            child: const Text('Öffnen'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('recipe-name')),
      'Neue Reispfanne',
    );
    await tester.enterText(find.byKey(const ValueKey('recipe-minutes')), '25');
    await tester.enterText(find.byKey(const ValueKey('recipe-servings')), '3');
    await tester.ensureVisible(find.byKey(const ValueKey('ingredient-name-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ingredient-name-0')),
      'Basmatireis',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ingredient-amount-0')),
      '225,5',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('recipe-steps')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('recipe-steps')),
      'Reis waschen.\nReis garen.',
    );
    final button = find.widgetWithText(FilledButton, 'Rezept speichern');
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(store.payload!['name'], 'Neue Reispfanne');
    expect(store.payload!['servings'], 3);
    expect(store.payload!['steps'], ['Reis waschen.', 'Reis garen.']);
    expect((store.payload!['ingredients'] as List).single['quantity'], 225.5);
    expect(store.payload!['is_published'], isFalse);
    expect(find.text('Öffnen'), findsOneWidget);
  });
  testWidgets('Bearbeitung lädt vorhandene Werte und Fehler erhält Eingaben', (
    tester,
  ) async {
    final store = AdminMemoryStore()..fail = true;
    final recipe = Recipe(
      id: 'rice',
      name: 'Reis',
      minutes: 15,
      servings: 2,
      ingredients: [const IngredientAmount('rice', 'Reis', 100, 'g')],
      steps: ['Garen.'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeEditorPage(
          repository: store,
          existing: AdminRecipe(recipe, published: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reis'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('recipe-name')),
      'Geänderter Reis',
    );
    final button = find.widgetWithText(FilledButton, 'Rezept speichern');
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Speichern fehlgeschlagen'), findsOneWidget);
    expect(find.text('Geänderter Reis'), findsOneWidget);
  });
  testWidgets(
    'Löschen erfordert Bestätigung und Papierkorb bietet Wiederherstellung',
    (tester) async {
      final store = AdminMemoryStore()
        ..items.add(
          AdminRecipe(DemoRecipeRepository().getAll().first, published: true),
        );
      await tester.pumpWidget(
        MaterialApp(home: AdminRecipesPage(repository: store)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In Papierkorb'));
      await tester.pumpAndSettle();
      expect(store.items.single.deleted, isTrue);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wiederherstellen'));
      await tester.pumpAndSettle();
      expect(store.items.single.deleted, isFalse);
    },
  );
  testWidgets('Fehlgeschlagenes Laden der Zutaten kann wiederholt werden', (
    tester,
  ) async {
    final store = AdminMemoryStore()..ingredientLoadFails = true;
    final recipe = Recipe(
      id: 'rice',
      name: 'Reis',
      minutes: 15,
      servings: 2,
      ingredients: [const IngredientAmount('rice', 'Reis', 100, 'g')],
      steps: ['Garen.'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeEditorPage(
          repository: store,
          existing: AdminRecipe(recipe, published: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Zutaten konnten nicht geladen'),
      findsOneWidget,
    );
    store.ingredientLoadFails = false;
    await tester.tap(find.text('Zutaten erneut laden'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recipe-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
