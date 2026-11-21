import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';

import 'scroll_helpers.dart';
import 'account_household_test.dart' as account;

void main() {
  for (final shared in [false, true]) {
    testWidgets(
      'Confirmed receipt saves to ${shared ? 'household' : 'customer account'}',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final backend = account.AccountBackend();
        backend.documents[account.accountA] = {
          'revision': 1,
          'data': {
            'pantry': <dynamic>[],
            if (shared) 'activeHouseholdId': account.householdId,
          },
        };
        final client = (await tester.runAsync(
          () async => backend.client(account.accountA),
        ))!;
        await tester.runAsync(() => account.login(client));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(client.dispose);
        });
        await tester.pumpWidget(account.planning(client));
        await account.settleAccount(tester);
        await tester.tap(find.text('Vorrat'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Bontext einfügen'));
        await tester.tap(find.text('Bontext einfügen'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'REWE\nJOGHURT 1,29 B\nSUMME 1,29',
        );
        await tester.tap(find.text('Artikel erkennen'));
        await tester.pumpAndSettle();
        expect(backend.documents[account.accountA]!['data']['pantry'], isEmpty);
        await reveal(
          tester,
          find.text('Auswahl, Mengen und Lagerorte geprüft'),
        );
        await tester.tap(find.text('Auswahl, Mengen und Lagerorte geprüft'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1 Produkt zum Vorrat hinzufügen'));
        await account.settleAccount(tester);
        final data = backend.documents[account.accountA]!['data'] as Map;
        final stock = shared
            ? backend.shared['pantry'] as List
            : data['pantry'] as List;
        expect(stock, hasLength(1));
        expect(stock.single['name'], 'JOGHURT');
        expect(stock.single['sourceReceiptIds'], hasLength(1));
        expect(data['importedReceiptIds'], hasLength(1));
        expect(backend.documents[account.accountB], isNull);
        if (shared) {
          expect(data['pantry'], isEmpty);
          expect(backend.shared.containsKey('importedReceiptIds'), isFalse);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Real receipt review imports only selected food after confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const PlanningPage(recipes: [], isDemo: true),
        ),
      );
      await tester.tap(find.text('Vorrat'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Bontext einfügen'));
      await tester.tap(find.text('Bontext einfügen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'REWE\nJOGHURT 1,29 B\nMILCH 2,18 B\n2 Stk x 1,09\nMUELLBEUTEL 1,99 A\nSUMME 5,46',
      );
      await tester.tap(find.text('Artikel erkennen'));
      await tester.pumpAndSettle();
      expect(find.text('3 Positionen erkannt · 2 ausgewählt'), findsOneWidget);
      final add = find.widgetWithText(
        FilledButton,
        '2 Produkte zum Vorrat hinzufügen',
      );
      expect(tester.widget<FilledButton>(add).onPressed, isNull);
      await reveal(tester, find.text('Auswahl, Mengen und Lagerorte geprüft'));
      await tester.tap(find.text('Auswahl, Mengen und Lagerorte geprüft'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('JOGHURT'), findsOneWidget);
      expect(find.text('MILCH'), findsOneWidget);
      expect(find.text('MUELLBEUTEL'), findsNothing);
      expect(find.text('2 Packungen'), findsOneWidget);
      await tester.tap(find.text('JOGHURT'));
      await tester.pumpAndSettle();
      expect(find.text('Lebensmittel bearbeiten'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Vorrat hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bontext einfügen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'REWE\nJOGHURT 1,29 B\nMILCH 2,18 B\n2 Stk x 1,09\nMUELLBEUTEL 1,99 A\nSUMME 5,46',
      );
      await tester.tap(find.text('Artikel erkennen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('bereits übernommen'), findsOneWidget);
      expect(find.text('JOGHURT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
