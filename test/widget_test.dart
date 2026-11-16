import 'scroll_helpers.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/app/kochmaster_app.dart';

void main() {
  testWidgets('Rezept planen und Zutaten anzeigen', (tester) async {
    await tester.pumpWidget(const KochmasterApp());
    await reveal(tester, find.widgetWithText(FilledButton, 'Wochenplan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Wochenplan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Korb'));
    await tester.pumpAndSettle();
    expect(find.text('Tomaten'), findsOneWidget);
    expect(find.text('300.0 g'), findsOneWidget);
  });
}
