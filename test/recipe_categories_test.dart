import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_editor_page.dart';

import 'admin_recipes_test.dart' show AdminMemoryStore;

const meat = Recipe(
  id: 'meat',
  name: 'Fleischgericht',
  minutes: 20,
  servings: 2,
  categories: {'meat', 'main'},
  favoriteCount: 7,
  ingredients: [IngredientAmount('meat', 'Fleisch', 100, 'g')],
  steps: ['Garen.'],
);
const salad = Recipe(
  id: 'salad',
  name: 'Grüner Salat',
  minutes: 10,
  servings: 2,
  categories: {'vegan', 'salad'},
  favoriteCount: 3,
  ingredients: [IngredientAmount('salad', 'Salat', 100, 'g')],
  steps: ['Mischen.'],
);

class CategoryAdminStore extends AdminMemoryStore {
  @override
  Future<List<CatalogIngredient>> ingredients() async => [
    const CatalogIngredient('rice', 'Reis'),
    const CatalogIngredient('salad', 'Salat'),
  ];
}

void main() {
  test('Kategorien bleiben in Plan-Snapshots erhalten', () {
    expect(recipeFromSnapshot(recipeSnapshot(meat)).categories, {
      'meat',
      'main',
    });
  });
  testWidgets('Kategoriefilter, echte Beliebtheit und fixierter Rezeptkopf', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PlanningPage(isDemo: true, recipes: const [meat, salad]),
      ),
    );
    await tester.tap(find.text('Rezepte'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Rezeptauswahl ändern'), findsOneWidget);
    await tester.tap(find.text('Fleisch'));
    await tester.pumpAndSettle();
    expect(find.text('Suchergebnisse'), findsOneWidget);
    expect(find.text('Fleischgericht'), findsOneWidget);
    expect(find.text('Grüner Salat'), findsNothing);
    await tester.tap(find.text('Zurücksetzen'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('compact-recipe-card-meat')),
      findsWidgets,
    );
    expect(find.text('Rezepte entdecken').hitTestable(), findsOneWidget);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Rezeptauswahl ändern'));
    await tester.pumpAndSettle();
    expect(find.text('Meine Rezeptsammlung'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Kategorien durchsuchen und vegetarisch inklusive vegan filtern',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PlanningPage(isDemo: true, recipes: const [meat, salad]),
        ),
      );
      await tester.tap(find.text('Rezepte'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kategorien durchsuchen'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Soßen & Dips'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Kategorie suchen'),
        've',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Vegetarisch'));
      await tester.pumpAndSettle();
      expect(find.text('Suchergebnisse'), findsOneWidget);
      expect(find.text('Grüner Salat'), findsOneWidget);
      expect(find.text('Fleischgericht'), findsNothing);
      await tester.tap(find.byTooltip('Kategorien durchsuchen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Kategorie suchen'),
        'unbekannt',
      );
      await tester.pumpAndSettle();
      expect(find.text('Keine Kategorie gefunden.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Editor lädt Kategorien und speichert Änderungen', (
    tester,
  ) async {
    final store = CategoryAdminStore();
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeEditorPage(
          repository: store,
          existing: const AdminRecipe(salad, published: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fish = find.widgetWithText(FilterChip, 'Fisch');
    await tester.scrollUntilVisible(
      fish,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(fish);
    await tester.pumpAndSettle();
    await tester.tap(fish);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Rezept speichern');
    await tester.scrollUntilVisible(
      save,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(store.payload!['categories'], containsAll(['fish', 'salad']));
    expect(store.payload!['categories'], isNot(contains('vegan')));
    await tester.pumpWidget(const SizedBox());
  });
}
