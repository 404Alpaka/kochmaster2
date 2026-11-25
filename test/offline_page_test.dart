import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/app/kochmaster_app.dart';
import 'package:kochmaster/core/local_store.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/data/offline_cache.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

import 'account_household_test.dart' as account;
import 'planning_page_test.dart' show MemoryWeekStore;
import 'scroll_helpers.dart';

final _recipes = DemoRecipeRepository().getAll();
final _week = mondayOf(DateTime.now());

Future<void> _restartStore() async {
  await LocalStore.instance.flush();
  LocalStore.instance = LocalStore(
    preferences: LocalStore.instance.preferences,
  );
  await LocalStore.instance.initialize();
}

void main() {
  testWidgets(
    'Guest plans and shopping checks survive a full application restart',
    (tester) async {
      await tester.pumpWidget(const KochmasterApp());
      await tester.tap(find.text('Rezepte').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tomaten-Spinat');
      await tester.pumpAndSettle();
      final action = find.byTooltip('Rezeptaktionen für Tomaten-Spinat-Pasta');
      await reveal(tester, action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zum Wochenplan hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Montag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Korb').last);
      await tester.pumpAndSettle();
      final noodles = find.widgetWithText(CheckboxListTile, 'Nudeln');
      await reveal(tester, noodles);
      await tester.tap(noodles);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await _restartStore();
      await tester.pumpWidget(const KochmasterApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Korb').last);
      await tester.pumpAndSettle();
      await reveal(tester, noodles);
      expect(tester.widget<CheckboxListTile>(noodles).value, isTrue);
      expect(find.text('200.0 g'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final shared in [false, true]) {
    testWidgets(
      '${shared ? 'Household' : 'Private'} offline checks survive restart and merge with a newer cloud week',
      (tester) async {
        final backend = account.AccountBackend();
        backend.documents[account.accountA] = {
          'revision': 1,
          'data': {
            if (shared) 'activeHouseholdId': account.householdId,
            'pantry': [
              {'name': 'Privater Reis', 'amount': '1 kg'},
            ],
          },
        };
        backend.shared = {
          'pantry': [
            {'name': 'Haushaltsreis', 'amount': '2 kg'},
          ],
        };
        backend.sharedWeek = {
          ...WeeklyPlan(meals: {0: PlannedMeal(_recipes.first, 2)}).toJson(),
          'revision': 1,
        };
        final client = (await tester.runAsync(
          () async => backend.client(account.accountA),
        ))!;
        await tester.runAsync(() => account.login(client));
        final store = MemoryWeekStore();
        store.rows[dateKey(_week)] = WeeklyPlan(
          meals: {0: PlannedMeal(_recipes.first, 2)},
        ).toJson();
        Future<void> mount() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: PlanningPage(
                recipes: _recipes,
                isDemo: false,
                client: client,
                user: client.auth.currentUser,
                store: store,
              ),
            ),
          );
          await account.settleAccount(tester);
        }

        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(client.dispose);
        });
        await mount();
        await tester.pumpWidget(const SizedBox());
        await _restartStore();
        backend.offline = true;
        backend.writes.clear();
        await mount();
        expect(find.textContaining('gespeicherter Stand'), findsOneWidget);
        await tester.tap(find.text('Plan').last);
        await tester.pumpAndSettle();
        expect(find.text('Wochenplan bearbeiten'), findsNothing);
        await tester.tap(find.text('Vorrat').last);
        await tester.pumpAndSettle();
        expect(
          find.text(shared ? 'Haushaltsreis' : 'Privater Reis'),
          findsOneWidget,
        );
        await tester.tap(find.text('Korb').last);
        await tester.pumpAndSettle();
        final noodles = find.widgetWithText(CheckboxListTile, 'Nudeln');
        await reveal(tester, noodles);
        await tester.tap(noodles);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(noodles).value, isTrue);
        expect(store.saveCalls, 0);
        expect(backend.writes, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await _restartStore();
        await mount();
        await tester.tap(find.text('Korb').last);
        await tester.pumpAndSettle();
        await reveal(tester, noodles);
        expect(tester.widget<CheckboxListTile>(noodles).value, isTrue);
        final remote = WeeklyPlan(
          meals: {
            0: PlannedMeal(_recipes.first, 2),
            1: PlannedMeal(_recipes.last, 2),
          },
          checked: {('rice', 'g')},
        ).toJson();
        if (shared) {
          backend.sharedWeek = {...remote, 'revision': 2};
        } else {
          store.rows[dateKey(_week)] = remote;
        }
        backend.offline = false;
        await tester.tap(find.text('Cloudstand aktualisieren'));
        await account.settleAccount(tester);
        final saved = WeeklyPlan.fromJson(
          shared ? backend.sharedWeek : store.rows[dateKey(_week)]!,
          _recipes,
        );
        expect(saved.meals, hasLength(2));
        expect(saved.checked, {('pasta', 'g'), ('rice', 'g')});
        final cache = OfflineCache(
          project: client.rest.url,
          user: account.accountA,
        );
        expect(
          cache
              .readWeek(_week, shared ? account.householdId : 'private')!
              .pending,
          isFalse,
        );
        expect(
          shared
              ? backend.writes.where((w) => w['kind'] == 'week').length
              : store.saveCalls,
          1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
