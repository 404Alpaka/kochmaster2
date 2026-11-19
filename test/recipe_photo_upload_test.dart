import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/recipes/data/admin_recipe_repository.dart';
import 'package:kochmaster/features/recipes/data/recipe_image_uploader.dart';
import 'package:kochmaster/features/recipes/presentation/recipe_editor_page.dart';

import 'admin_recipes_test.dart' show AdminMemoryStore;

import 'package:kochmaster/features/recipes/domain/recipe.dart';

import 'scroll_helpers.dart';

class PhotoUploadStub implements RecipeImageUploader {
  int calls = 0;
  bool fail = false;
  @override
  Future<String> upload(RecipePhoto photo) async {
    calls++;
    if (fail) throw const StorageException('offline');
    return 'https://example.com/uploaded.jpg';
  }
}

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
  test('Photo validation rejects unsupported files and oversize images', () {
    expect(() => RecipePhoto.fromBytes(Uint8List(12)), throwsFormatException);
    expect(
      () => RecipePhoto.fromBytes(Uint8List(RecipePhoto.maxBytes + 1)),
      throwsFormatException,
    );
    expect(
      RecipePhoto.fromBytes(File('assets/images/rice.jpg').readAsBytesSync())
          .contentType,
      'image/jpeg',
    );
  });
  for (final photoSource in ImageSource.values) {
    for (final failedFirst in [false, true]) {
      testWidgets(
        'Photo $photoSource preview, durable upload and retry: $failedFirst',
        (tester) async {
          final store = AdminMemoryStore();
          final uploader = PhotoUploadStub()..fail = failedFirst;
          ImageSource? source;
          await tester.pumpWidget(
            MaterialApp(
              home: RecipeEditorPage(
                repository: store,
                imageUploader: uploader,
                existing: AdminRecipe(
                  recipe('Reis', image: 'assets/images/rice.jpg'),
                  published: true,
                ),
                pickPhoto: (value) async {
                  source = value;
                  return XFile.fromData(
                    File('assets/images/rice.jpg').readAsBytesSync(),
                    name: 'dish.jpg',
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Bild ändern'));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await tester.tap(
              find.text(
                photoSource == ImageSource.camera
                    ? 'Foto aufnehmen'
                    : 'Aus Galerie auswählen',
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          expect(source, photoSource);
          expect(
            find.text('Dein Foto · wird beim Speichern hochgeladen'),
            findsOneWidget,
          );
          expect(uploader.calls, 0);
          final save = find.widgetWithText(FilledButton, 'Rezept speichern');
          await reveal(tester, save);
          await tester.ensureVisible(save);
          await tester.pumpAndSettle();
          await tester.tap(save);
          await tester.pumpAndSettle();
          if (failedFirst) {
            expect(store.payload, isNull);
            uploader.fail = false;
            await reveal(tester, save);
            await tester.tap(save);
            await tester.pumpAndSettle();
          }
          expect(
            store.payload!['image_url'],
            'https://example.com/uploaded.jpg',
          );
          expect(uploader.calls, failedFirst ? 2 : 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
