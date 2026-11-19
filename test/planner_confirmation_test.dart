import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/features/meal_planning/domain/planning_diner.dart';

import 'account_household_test.dart'
    show AccountBackend, accountA, householdId, login, planning, settleAccount;
import 'scroll_helpers.dart';

void main() {
  testWidgets(
    'rules changed by another member block confirmation of stale automatic proposal',
    (tester) async {
      final backend = AccountBackend();
      backend.documents[accountA] = {
        'revision': 1,
        'data': {'activeHouseholdId': householdId},
      };
      backend.shared = {
        'pantry': [],
        'survey': {
          'completed': true,
          'diet': 'Ohne Einschränkung',
          'exclusions': [],
          'days': 2,
          'minutes': 30,
          'startDay': 0,
        },
        'servings': 2,
        'householdDinerRules': {
          accountA: const PlanningDiner(
            id: accountA,
            name: 'A',
            confirmed: true,
          ).toJson(),
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
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('week-primary-action')));
      await tester.tap(find.byKey(const ValueKey('week-primary-action')));
      await settleAccount(tester);
      expect(find.text('Deine Woche. Dein Mix.'), findsOneWidget);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      backend.shared = {
        ...backend.shared,
        'householdDinerRules': {
          accountA: const PlanningDiner(
            id: accountA,
            name: 'A',
            confirmed: true,
            exclusions: {'Milch'},
          ).toJson(),
        },
      };
      backend.stateRevision++;
      await tester.tap(find.text('Wochenplan bestätigen'));
      await settleAccount(tester);
      await tester.pumpAndSettle();
      expect(find.text('Vorschlag bitte anpassen'), findsOneWidget);
      expect(backend.writes.where((w) => w['kind'] == 'week'), isEmpty);
    },
  );
}
