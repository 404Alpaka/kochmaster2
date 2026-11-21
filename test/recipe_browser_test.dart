import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/app/kochmaster_app.dart';

import 'scroll_helpers.dart';

void main() {
  testWidgets(
    'Rezeptaktionen merken, favorisieren und Vorschläge rückgängig ausblenden',
    (tester) async {
      await tester.pumpWidget(const KochmasterApp());
      await tester.tap(find.text('Rezepte'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tomaten-Spinat');
      await tester.pumpAndSettle();
      Future<void> menu() async {
        await reveal(
          tester,
          find.byTooltip('Rezeptaktionen für Tomaten-Spinat-Pasta'),
        );
        await tester.tap(
          find.byTooltip('Rezeptaktionen für Tomaten-Spinat-Pasta'),
        );
        await tester.pumpAndSettle();
      }

      await menu();
      expect(find.widgetWithText(ListTile, 'Rezept ansehen'), findsOneWidget);
      expect(find.text('Zum Wochenplan hinzufügen'), findsOneWidget);
      expect(find.text('Nicht mehr vorschlagen'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Merken'));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Rezeptaktionen für Tomaten-Spinat-Pasta'),
        findsOneWidget,
      );
      await menu();
      expect(find.text('Nicht mehr merken'), findsOneWidget);
      await tester.tap(find.text('Als Favorit speichern'));
      await tester.pumpAndSettle();
      await menu();
      expect(find.text('Aus Favoriten entfernen'), findsOneWidget);
      await tester.tap(find.text('Nicht mehr vorschlagen'));
      await tester.pumpAndSettle();
      expect(
        find.text('Rezept wird nicht mehr vorgeschlagen.'),
        findsOneWidget,
      );
      expect(find.text('Tomaten-Spinat-Pasta'), findsNothing);
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(find.text('Tomaten-Spinat-Pasta'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Auswahl zeigt nur gemerkte Rezepte und öffnet Erstellen und Import',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const KochmasterApp());
      await tester.tap(find.text('Rezepte'));
      await tester.pumpAndSettle();
      final heart = tester.getCenter(find.byTooltip('Rezeptauswahl ändern'));
      final create = tester.getCenter(
        find.byTooltip('Eigenes Rezept erstellen'),
      );
      final import = tester.getCenter(find.byTooltip('Rezept importieren'));
      expect(create.dx, closeTo(heart.dx, 1));
      expect(create.dy, lessThan(heart.dy));
      expect(import.dx, lessThan(create.dx));
      expect(import.dy, closeTo(heart.dy, 1));
      expect(
        heart.dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('app-bottom-dock'))).dy,
        ),
      );
      expect(find.text('Erstellen'), findsNothing);
      expect(find.text('Importieren'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Tomaten-Spinat');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Rezeptaktionen für Tomaten-Spinat-Pasta'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Merken'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Suche löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rezeptauswahl ändern'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gemerkt').last);
      await tester.pumpAndSettle();
      expect(find.text('Rezept des Tages'), findsNothing);
      expect(find.text('Beliebte Rezepte'), findsNothing);
      expect(find.text('Gemerkte Rezepte'), findsOneWidget);
      expect(find.text('Tomaten-Spinat-Pasta'), findsOneWidget);
      expect(find.text('Weitere Treffer'), findsNothing);
      await tester.tap(find.byTooltip('Eigenes Rezept erstellen'));
      await tester.pumpAndSettle();
      expect(find.text('Dein eigenes Rezept.'), findsOneWidget);
      await tester.tap(find.text('Rezepte'));
      await tester.pumpAndSettle();
      // Return from the editor through its collection back action.
      await tester.tap(find.text('Meine Sammlung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rezepte entdecken'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rezept importieren'));
      await tester.pumpAndSettle();
      expect(find.text('Lieblingsrezept gefunden?'), findsOneWidget);
      await tester.tap(find.text('Rezepte entdecken'));
      await tester.pumpAndSettle();
      expect(find.text('Lieblingsrezept gefunden?'), findsNothing);
      expect(find.text('Rezepte entdecken'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Rezeptsuche, Löschen und verständliche leere Favoriten', (
    tester,
  ) async {
    await tester.pumpWidget(const KochmasterApp());
    await tester.tap(find.text('Rezepte'));
    await tester.pumpAndSettle();
    expect(find.text('Rezepte entdecken'), findsOneWidget);
    expect(find.text('mise.'), findsNothing);
    expect(find.textContaining('Personen'), findsNothing);
    await tester.enterText(find.byType(TextField), '  Spinat  ');
    await tester.pumpAndSettle();
    expect(find.text('Suchergebnisse'), findsOneWidget);
    await tester.tap(find.byTooltip('Suche löschen'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.byTooltip('Rezeptauswahl ändern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoriten').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Noch keine Favoriten'), findsOneWidget);
    await tester.tap(find.text('Zurücksetzen'));
    await tester.pumpAndSettle();
    expect(find.text('Rezept des Tages'), findsOneWidget);
    expect(find.byTooltip('Kategorien durchsuchen'), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('Kategorien durchsuchen')).dx,
      lessThan(tester.getCenter(find.text('Alle')).dx),
    );
    expect(find.byTooltip('Eigenes Rezept erstellen'), findsOneWidget);
    expect(find.byTooltip('Rezept importieren'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
