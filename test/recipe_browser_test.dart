import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/app/kochmaster_app.dart';
import 'scroll_helpers.dart';

void main() {
  testWidgets('Rezeptaktionen merken, favorisieren und Vorschläge rückgängig ausblenden', (tester) async {
    await tester.pumpWidget(const KochmasterApp());
    await tester.tap(find.text('Rezepte'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tomaten-Spinat');
    await tester.pumpAndSettle();
    Future<void> menu() async {
      await reveal(tester, find.text('Mehr'));
      await tester.tap(find.text('Mehr'));
      await tester.pumpAndSettle();
    }
    await menu();
    expect(find.text('Rezept ansehen'), findsOneWidget);
    expect(find.text('Zum Wochenplan hinzufügen'), findsOneWidget);
    expect(find.text('Nicht mehr vorschlagen'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Merken'));
    await tester.pumpAndSettle();
    expect(find.text('Gemerkt'), findsWidgets);
    await menu();
    expect(find.text('Nicht mehr merken'), findsOneWidget);
    await tester.tap(find.text('Als Favorit speichern'));
    await tester.pumpAndSettle();
    await menu();
    expect(find.text('Aus Favoriten entfernen'), findsOneWidget);
    await tester.tap(find.text('Nicht mehr vorschlagen'));
    await tester.pumpAndSettle();
    expect(find.text('Rezept wird nicht mehr vorgeschlagen.'), findsOneWidget);
    expect(find.text('Tomaten-Spinat-Pasta'), findsNothing);
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(find.text('Tomaten-Spinat-Pasta'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Rezeptsuche, Löschen und verständliche leere Favoriten', (tester) async {
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
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Favoriten'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Noch keine Favoriten'), findsOneWidget);
    await tester.tap(find.text('Zurücksetzen'));
    await tester.pumpAndSettle();
    expect(find.text('Rezept des Tages'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Aus Vorrat'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
