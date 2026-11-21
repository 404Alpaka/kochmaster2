import 'scroll_helpers.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/app/kochmaster_app.dart';

void main() {
  testWidgets('Rezept planen und Zutaten anzeigen', (tester) async {
    await tester.pumpWidget(const KochmasterApp());
    await tester.tap(find.text('Rezepte'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tomaten-Spinat');
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byTooltip('Rezeptaktionen für Tomaten-Spinat-Pasta'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rezeptaktionen für Tomaten-Spinat-Pasta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zum Wochenplan hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Korb'));
    await tester.pumpAndSettle();
    if (find.text('Selbst einkaufen').evaluate().isNotEmpty) {
      await tester.tap(find.text('Selbst einkaufen').last);
      await tester.pumpAndSettle();
    }
    expect(find.text('Tomaten'), findsOneWidget);
    expect(find.text('300.0 g'), findsOneWidget);
  });
}
