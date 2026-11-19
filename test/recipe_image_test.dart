import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_image.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_editor_page.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';

import 'admin_recipes_test.dart' show AdminMemoryStore;

void main() {
  Recipe recipe(String name, {String? image}) => Recipe(
    id: 'test',
    name: name,
    minutes: 15,
    servings: 2,
    imageUrl: image,
    ingredients: const [IngredientAmount('rice', 'Reis', 100, 'g')],
    steps: const ['Garen.'],
  );
  test('Ohne explizites Bild werden keine fremden Gerichte zugeordnet', () {
    for (final name in [
      'Ofenkartoffeln mit Knoblauchquark',
      'Champignon-Rahm-Pasta',
      'Thunfischsalat',
    ]) {
      expect(recipeImageSource(recipe(name)), isNull);
      expect(
        recipeImageCaption(recipe(name)),
        'Noch kein Rezeptbild hinterlegt',
      );
    }
    expect(
      recipeImageSource(recipe('Test', image: 'https://example.com/image.jpg')),
      'https://example.com/image.jpg',
    );
    expect(
      recipeImageCaption(recipe('Test', image: 'assets/images/rice.jpg')),
      'Stockfoto · Serviervorschlag',
    );
  });
  testWidgets(
    'Fehlendes Bild zeigt einen neutralen Platzhalter auch bei kleinen Kacheln',
    (tester) async {
      for (final height in [64.0, 180.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: RecipeImage(null, height: height)),
          ),
        );
        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
        expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Ein unpassendes Bild lässt sich im Editor entfernen und speichern',
    (tester) async {
      final store = AdminMemoryStore();
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeEditorPage(
            repository: store,
            existing: AdminRecipe(
              recipe('Reis', image: 'assets/images/rice.jpg'),
              published: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bild ändern'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kein Bild'));
      await tester.pumpAndSettle();
      expect(find.text('Noch kein Rezeptbild hinterlegt'), findsOneWidget);
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
      expect(store.payload!['image_url'], isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
