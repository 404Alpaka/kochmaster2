import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_editor_page.dart';

import 'admin_recipes_test.dart' show AdminMemoryStore;

const recipes = [
  Recipe(
    id: 'a',
    name: 'Reis',
    minutes: 20,
    servings: 2,
    ingredients: [IngredientAmount('rice', 'Reis', 100, 'g')],
    steps: ['Garen.'],
  ),
  Recipe(
    id: 'b',
    name: 'Ein sehr langer Rezeptname mit vielen weiteren Worten',
    minutes: 120,
    servings: 12,
    ingredients: [IngredientAmount('rice', 'Reis', 100, 'g')],
    steps: ['Garen.'],
  ),
  Recipe(
    id: 'c',
    name: 'Ofenreis mit Gemüse',
    minutes: 40,
    servings: 2,
    ingredients: [IngredientAmount('rice', 'Reis', 100, 'g')],
    steps: ['Garen.'],
  ),
  Recipe(
    id: 'd',
    name: 'Reis mit Tomaten',
    minutes: 15,
    servings: 2,
    ingredients: [IngredientAmount('rice', 'Reis', 100, 'g')],
    steps: ['Garen.'],
  ),
];

class ActionStore extends AdminMemoryStore {
  @override
  Future<void> save(Map<String, dynamic> recipe) async {
    await super.save(recipe);
    final index = items.indexWhere((r) => r.recipe.id == recipe['id']);
    items[index] = AdminRecipe(
      recipeFromSnapshot(recipe),
      published: recipe['is_published'] as bool,
    );
  }
}

void main() {
  Future<ActionStore> open(WidgetTester tester, {required bool admin}) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ActionStore()
      ..items.addAll(recipes.map((r) => AdminRecipe(r, published: true)));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PlanningPage(
          isDemo: true,
          recipes: recipes,
          adminRepository: admin ? store : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rezepte'));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> menu(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Reis');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Rezeptaktionen für Reis'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rezeptaktionen für Reis'));
    await tester.pumpAndSettle();
  }

  testWidgets('Only admins see creation shortcut and management actions', (
    tester,
  ) async {
    await open(tester, admin: false);
    expect(find.byTooltip('Rezept erstellen'), findsNothing);
    await menu(tester);
    expect(find.text('Rezept bearbeiten'), findsNothing);
    expect(find.text('Rezept löschen'), findsNothing);
    expect(find.text('In Entwürfe verschieben'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Admin plus opens creation and actions open editing', (
    tester,
  ) async {
    await open(tester, admin: true);
    await tester.tap(find.byTooltip('Rezept erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('Neues Rezept'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Rezept speichern').hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await menu(tester);
    await tester.tap(find.text('Rezept bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeEditorPage), findsOneWidget);
    expect(find.text('Rezept bearbeiten'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final deleting in [false, true]) {
    testWidgets(
      'Admin ${deleting ? 'deletes' : 'unpublishes'} with confirmation',
      (tester) async {
        final store = await open(tester, admin: true);
        await menu(tester);
        await tester.tap(
          find.text(deleting ? 'Rezept löschen' : 'In Entwürfe verschieben'),
        );
        await tester.pumpAndSettle();
        final confirm = find.widgetWithText(
          FilledButton,
          deleting ? 'In Papierkorb' : 'In Entwürfe verschieben',
        );
        expect(store.items.every((r) => r.published && !r.deleted), isTrue);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(
          store.items.where((r) => deleting ? r.deleted : !r.published).length,
          1,
        );
        if (!deleting) {
          expect(
            (store.payload!['ingredients'] as List).single['quantity'],
            100,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('Compact recipe tiles have matching heights on mobile', (
    tester,
  ) async {
    await open(tester, admin: false);
    await tester.scrollUntilVisible(
      find.text('4 von 4 Rezepten'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final cards = find.byWidgetPredicate(
      (widget) =>
          widget is Card &&
          widget.key is ValueKey<String> &&
          ((widget.key as ValueKey<String>).value.startsWith(
            'compact-recipe-card-',
          )),
    );
    expect(cards.evaluate().length, greaterThanOrEqualTo(2));
    final height = tester.getSize(cards.first).height;
    for (var i = 1; i < cards.evaluate().length; i++) {
      expect(tester.getSize(cards.at(i)).height, height);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
