import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/features/meal_planning/domain/planning_diner.dart';
import 'package:kochmaster/features/meal_planning/presentation/household_diners_page.dart';

import 'account_household_test.dart'
    show AccountBackend, accountA, householdId, login, planning, settleAccount;
import 'scroll_helpers.dart';

void main() {
  testWidgets(
    'household diner declarations persist to shared state without personal notes',
    (tester) async {
      final backend = AccountBackend();
      backend.documents[accountA] = {
        'revision': 1,
        'data': {
          'activeHouseholdId': householdId,
          'recipeNotes': {'private': 'weniger Salz'},
          'recipeRatings': {'private': 5},
        },
      };
      final client = (await tester.runAsync(
        () async => backend.client(accountA),
      ))!;
      await tester.runAsync(() => login(client));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(client.dispose);
      });
      await tester.pumpWidget(planning(client));
      await settleAccount(tester);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zum Haushalt'));
      await tester.pumpAndSettle();
      final open = find.text('Mitessende & feste Regeln');
      await reveal(tester, open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(HouseholdDinersPage), findsOneWidget);
      expect(find.text('Feste Regeln noch unbekannt'), findsOneWidget);
      await tester.tap(find.text('Feste Regeln bearbeiten'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Milch'));
      await tester.pumpAndSettle();
      final declaration = find.widgetWithText(
        CheckboxListTile,
        'Angaben geprüft – auch keine Allergien ist eine ausdrückliche Angabe.',
      );
      await tester.ensureVisible(declaration);
      await tester.tap(declaration);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gemeinsame Regeln speichern'));
      await settleAccount(tester);
      final stored = Map<String, dynamic>.from(
        (backend.shared['householdDinerRules'] as Map)[accountA] as Map,
      );
      expect(PlanningDiner.fromJson(accountA, 'A', stored).exclusions, {
        'Milch',
      });
      expect(stored['confirmed'], isTrue);
      expect(backend.shared.containsKey('recipeNotes'), isFalse);
      expect(backend.shared.containsKey('recipeRatings'), isFalse);
      expect(backend.documents[accountA]!['data']['recipeNotes'], {
        'private': 'weniger Salz',
      });
    },
  );
}
