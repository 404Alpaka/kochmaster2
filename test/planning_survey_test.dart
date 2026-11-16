import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

import 'scroll_helpers.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('Umfrage, Entwurf und Bestätigung bei $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
        await tester.runAsync(() async {
          await ui.loadFontFromList(
            await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
            fontFamily: 'Roboto',
          );
          await ui.loadFontFromList(
            await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
            fontFamily: 'Ahem',
          );
          await ui.loadFontFromList(
            await File(
              'C:/Users/klaeh/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes(),
            fontFamily: 'MaterialIcons',
          );
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: const ValueKey('survey-preview'),
            child: PlanningPage(
              recipes: DemoRecipeRepository().getAll(),
              isDemo: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('CAPTURE_DESIGN')) return;
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('survey-preview')),
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/design').create(recursive: true);
          await File('build/design/$name-${width.toInt()}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> tap(String label) async {
        await reveal(tester, find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await capture('planning');
      await tap('Wochenplan erstellen');
      expect(find.text('1 von 4'), findsOneWidget);
      await capture('allergies');
      await tap('○  Erdnüsse');
      await tap('Weiter: Ernährungsweise');
      await tap('○  Vegetarisch');
      await tap('Weiter: Personen & Tage');
      await tap('Weiter: Kochzeit');
      await capture('cooking-time');
      await tap('Wochenvorschlag anzeigen');
      expect(find.text('Noch nicht genug passende Rezepte'), findsOneWidget);
      expect(find.text('Tomaten-Spinat-Pasta'), findsNothing);
      await tap('←  Antworten ändern');
      await tap('✓  Erdnüsse');
      await tap('Weiter: Ernährungsweise');
      await tap('○  Ohne Einschränkung');
      await tap('Weiter: Personen & Tage');
      await tap('Weiter: Kochzeit');
      await tap('Wochenvorschlag anzeigen');
      expect(find.text('Tomaten-Spinat-Pasta'), findsOneWidget);
      await tap('Wochenplan bestätigen');
      expect(find.text('Deine Woche steht.'), findsOneWidget);
      await tap('Wochenplan bearbeiten');
      expect(find.text('Deine Woche. Dein Mix.'), findsOneWidget);
      expect(find.text('Tomaten-Spinat-Pasta'), findsOneWidget);
      final freeDay = find.text('Tag freilassen').first;
      await reveal(tester, freeDay);
      await tester.tap(freeDay);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('←  Bearbeiten abbrechen'), delta: -150);
      await tester.tap(find.text('←  Bearbeiten abbrechen'));
      await tester.pumpAndSettle();
      expect(find.text('Tomaten-Spinat-Pasta'), findsOneWidget);
      await tap('Wochenplan bearbeiten');
      await reveal(tester, find.text('Tag freilassen').first);
      await tester.tap(find.text('Tag freilassen').first);
      await tester.pumpAndSettle();
      await tap('Wochenplan bestätigen');
      expect(find.text('Tomaten-Spinat-Pasta'), findsNothing);
      expect(find.text('1 Gerichte · 6 freie Tage'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
