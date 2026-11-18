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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('recipe-name')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('recipe-name')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('recipe-name')),
      'Neue Reispfanne',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('recipe-minutes')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('recipe-minutes')), '25');
    await tester.ensureVisible(find.byKey(const ValueKey('recipe-servings')));
    await tester.pumpAndSettle();
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('recipe-steps')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
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
    expect(store.payload!['verified_allergens'], isNull);
    expect(store.payload!['verified_diets'], isNull);
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
      verifiedAllergens: {'Soja'},
      verifiedDiets: {'Vegetarisch'},
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('recipe-name')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('recipe-name')));
    await tester.pumpAndSettle();
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
    await tester.scrollUntilVisible(
      find.textContaining('Speichern fehlgeschlagen'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Speichern fehlgeschlagen'), findsOneWidget);
    expect(find.text('Geänderter Reis'), findsWidgets);
    store.fail = false;
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(store.payload!['verified_allergens'], ['Soja']);
    expect(store.payload!['verified_diets'], ['Vegetarisch']);
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
      await tester.scrollUntilVisible(
        find.byTooltip('Löschen'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byTooltip('Löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In Papierkorb'));
      await tester.pumpAndSettle();
      expect(store.items.single.deleted, isTrue);
      await tester.scrollUntilVisible(
        find.text('Papierkorb 1'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Papierkorb 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Papierkorb 1'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Wiederherstellen'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Wiederherstellen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wiederherstellen'));
      await tester.pumpAndSettle();
      expect(store.items.single.deleted, isFalse);
    },
  );
  testWidgets(
    'Zutat wird mit aktueller Menge an der Cursorposition eingefügt',
    (tester) async {
      final recipe = Recipe(
        id: 'rice',
        name: 'Reis',
        minutes: 10,
        servings: 2,
        ingredients: [const IngredientAmount('rice', 'Reis', 100, 'g')],
        steps: ['Gare .'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeEditorPage(
            repository: AdminMemoryStore(),
            existing: AdminRecipe(recipe, published: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('recipe-steps')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('recipe-steps')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<TextFormField>(find.byKey(const ValueKey('recipe-steps')))
          .controller!;
      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.ensureVisible(find.text('Zutat einfügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zutat einfügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100 g Reis'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Gare ⟦100 g Reis⟧.');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Verknüpfte Mengen und Bildauswahl bleiben beim Speichern erhalten',
    (tester) async {
      final store = AdminMemoryStore();
      final recipe = Recipe(
        id: 'rice',
        name: 'Reis',
        minutes: 10,
        servings: 2,
        ingredients: [
          const IngredientAmount('rice', 'Reis', 100, 'g', stepKey: 'stable'),
        ],
        steps: ['Gare {{ingredient:stable}}.'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeEditorPage(
            repository: store,
            existing: AdminRecipe(recipe, published: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bild ändern'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bild ändern'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is Image &&
                  w.image is AssetImage &&
                  (w.image as AssetImage).assetName ==
                      'assets/images/pasta.jpg',
            )
            .last,
      );
      await tester.pumpAndSettle();
      Future<void> field(String key, String value) async {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(key)),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(ValueKey(key)), value);
        await tester.pumpAndSettle();
      }

      await field('recipe-servings', '4');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('ingredient-amount-0')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('ingredient-amount-0')),
            )
            .controller!
            .text,
        '200',
      );
      await field('ingredient-amount-0', '300');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('recipe-steps')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final controller = tester
          .widget<TextFormField>(find.byKey(const ValueKey('recipe-steps')))
          .controller!;
      expect(controller.text, 'Gare ⟦300 g Reis⟧.');
      await tester.scrollUntilVisible(
        find.text('Rezept speichern'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Rezept speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rezept speichern'));
      await tester.pumpAndSettle();
      expect(store.payload!['steps'], ['Gare {{ingredient:stable}}.']);
      expect(store.payload!['image_url'], 'assets/images/pasta.jpg');
      expect((store.payload!['ingredients'] as List).single['quantity'], 300);
      expect(
        (store.payload!['ingredients'] as List).single['step_key'],
        'stable',
      );
      expect(store.payload!['servings'], 4);
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('recipe-name')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('recipe-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
