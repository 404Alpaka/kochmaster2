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
    expect(find.text('mise.'), findsOneWidget);
    expect(find.text('Gutes Essen. Clever geplant.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Dein Vorrat. Dein nächstes Lieblingsgericht.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Vorrat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lebensmittel erfassen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextFormField).at(0), 'Tomaten');
    await tester.enterText(find.byType(TextFormField).at(1), '300 g');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Tomaten'), findsOneWidget);
    await tester.tap(find.text('Haushalt'));
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
    expect(find.text('Dein smarter Einkauf'), findsOneWidget);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Deine Woche'), findsOneWidget);
    await reveal(tester, find.text('Deine Woche'), delta: -150);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
