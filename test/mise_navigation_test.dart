import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/app/kochmaster_app.dart';

import 'scroll_helpers.dart';

void main() {
  testWidgets('mise Navigation, Spruchwechsel, Vorrat und Haushalt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const KochmasterApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Rezepte'));
    await tester.pumpAndSettle();
    expect(find.text('Rezepte entdecken'), findsOneWidget);
    expect(find.text('mise.'), findsNothing);
    await tester.tap(find.text('Vorrat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Manuell hinzufügen'));
    await tester.tap(find.text('Manuell hinzufügen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextFormField).at(0), 'Tomaten');
    await tester.enterText(find.byType(TextFormField).at(1), '300 g');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Tomaten'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zum Haushalt'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Zusammen isst’s besser.'), findsOneWidget);
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextFormField).at(0), '90');
    await tester.enterText(find.byType(TextFormField).at(1), '20');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('20,00 € von 90,00 €'), findsOneWidget);
    await tester.tap(find.text('Korb'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Dein Einkauf'), findsOneWidget);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Deine Woche'), findsOneWidget);
    await reveal(tester, find.text('Deine Woche'), delta: -150);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
