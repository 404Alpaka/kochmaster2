import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/meal_planning/presentation/food_preferences_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

import 'account_household_test.dart' as account;
import 'scroll_helpers.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('Profil bei $width und Schriftfaktor $scale', (tester) async {
        tester.view.physicalSize = Size(width, 964);
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
              await File(
                'C:/Users/klaeh/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes(),
              fontFamily: 'MaterialIcons',
            );
          });
        }
        final backend = account.AccountBackend();
        backend.documents[account.accountA] = {
          'revision': 1,
          'data': <String, dynamic>{},
        };
        final client = (await tester.runAsync(
          () async => backend.client(account.accountA),
        ))!;
        await tester.runAsync(() => account.login(client));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(client.dispose);
        });
        final user = User.fromJson({
          'id': account.accountA,
          'aud': 'authenticated',
          'email': 'fabian@beispiel.de',
          'user_metadata': {'first_name': 'Fabian'},
          'app_metadata': <String, dynamic>{},
          'created_at': '2026-11-22T00:00:00Z',
        });
        const preview = ValueKey('profile-preview');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: preview,
              child: PlanningPage(
                isDemo: false,
                recipes: DemoRecipeRepository().getAll(),
                client: client,
                user: user,
              ),
            ),
          ),
        );
        await account.settleAccount(tester);
        await tester.tap(find.byTooltip('Zum Profil'));
        await tester.pumpAndSettle();
        expect(find.text('Profil'), findsOneWidget);
        expect(find.text('Fabian'), findsOneWidget);
        expect(find.text('fabian@beispiel.de'), findsOneWidget);
        expect(
          find.textContaining('Kundennummer: ${account.accountA}'),
          findsOneWidget,
        );
        expect(find.text('Gespeichert'), findsOneWidget);
        expect(find.text('PLANUNGSBEREICH'), findsOneWidget);
        expect(find.text('Privat'), findsOneWidget);
        expect(find.text('Gemeinsam'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 390 &&
            scale == 1 &&
            const bool.fromEnvironment('CAPTURE_DESIGN')) {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(preview))
                .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/design').create(recursive: true);
            await File('build/design/profile-390.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await reveal(tester, find.text('Essenspräferenzen'));
        await tester.tap(find.text('Essenspräferenzen'));
        await tester.pumpAndSettle();
        expect(find.byType(FoodPreferencesPage), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Planregeln'), findsNothing);
        expect(find.text('Budget'), findsNothing);
        await reveal(tester, find.text('Meine Rezepte'));
        await tester.tap(find.text('Meine Rezepte'));
        await tester.pumpAndSettle();
        expect(find.text('Meine Rezepte'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Gastprofil fordert für gemeinsame Planung ein echtes Konto', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const PlanningPage(recipes: [], isDemo: true),
      ),
    );
    await tester.tap(find.byTooltip('Zum Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Gast'), findsOneWidget);
    expect(find.text('Nur auf diesem Gerät'), findsOneWidget);
    expect(find.text('Abmelden'), findsNothing);
    expect(find.text('Gespeichert'), findsNothing);
    await tester.tap(find.text('Gemeinsam'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Melde dich mit deinem Konto an'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
