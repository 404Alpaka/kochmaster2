import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/core/quantities.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';

import 'account_household_test.dart' as account;
import 'planning_page_test.dart' show MemoryWeekStore;
import 'scroll_helpers.dart';

final _week = mondayOf(DateTime.now());
Recipe _recipe(
  String id,
  List<IngredientAmount> ingredients, {
  int servings = 2,
}) => Recipe(
  id: id,
  name: id,
  minutes: 10,
  servings: servings,
  ingredients: ingredients,
  steps: const ['Zubereiten.'],
);

Future<void> _mount(
  WidgetTester tester,
  MemoryWeekStore store,
  List<Recipe> recipes, {
  SupabaseClient? client,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: PlanningPage(
        recipes: recipes,
        isDemo: client == null,
        store: store,
        client: client,
        user: client?.auth.currentUser,
      ),
    ),
  );
  await account.settleAccount(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    if (client != null) await tester.runAsync(client.dispose);
  });
}

Future<void> _addMissing(WidgetTester tester) async {
  await tester.tap(find.text('Vorrat').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Was kann ich kochen?'));
  await tester.pumpAndSettle();
  final card = find.ancestor(
    of: find.text('Reisgericht'),
    matching: find.byType(Card),
  );
  await reveal(tester, find.text('Reisgericht'));
  final button = find.descendant(
    of: card,
    matching: find.text('Fehlende Zutaten zur Einkaufsliste'),
  );
  await reveal(tester, button);
  await tester.tap(button);
  await account.settleAccount(tester);
}

void main() {
  testWidgets(
    'Legacy kg/l/piece checks survive unrelated edits and export, but changed demand reopens them',
    (tester) async {
      final mass = _recipe('Teig', const [
        IngredientAmount('flour', 'Mehl', 0.5, 'kg'),
        IngredientAmount('milk', 'Milch', 0.5, 'l'),
        IngredientAmount('banana', 'Bananen', 2, 'stk.'),
      ]);
      final other = _recipe('Salat', const [
        IngredientAmount('oil', 'Öl', 100, 'ml'),
      ]);
      final store = MemoryWeekStore();
      store.rows[dateKey(_week)] = WeeklyPlan(
        meals: {0: PlannedMeal(mass, 2), 1: PlannedMeal(other, 2)},
        checked: {('flour', 'kg'), ('milk', 'l'), ('banana', 'Stk.')},
      ).toJson();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _mount(tester, store, [mass, other]);
      await tester.tap(find.text('Korb').last);
      await tester.pumpAndSettle();
      final flour = find.widgetWithText(CheckboxListTile, 'Mehl');
      await reveal(tester, flour);
      expect(tester.widget<CheckboxListTile>(flour).value, isTrue);
      await reveal(tester, find.text('Einkaufsliste kopieren'), delta: -150);
      await tester.tap(find.text('Einkaufsliste kopieren'));
      await tester.pumpAndSettle();
      expect(copied, contains('[x] Mehl · 500 g'));
      expect(copied, contains('[x] Milch · 500 ml'));
      expect(copied, contains('[x] Bananen · 2 Stück'));
      expect(store.saveCalls, 0);
      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Di'));
      await tester.tap(find.text('Di'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('increase-1')));
      await tester.tap(find.byKey(const ValueKey('increase-1')));
      await tester.pumpAndSettle();
      expect(
        WeeklyPlan.fromJson(store.rows[dateKey(_week)]!, [mass, other]).checked,
        {('flour', 'g'), ('milk', 'ml'), ('banana', 'Stück')},
      );
      await reveal(tester, find.text('Mo'), delta: -150);
      await tester.tap(find.text('Mo'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('increase-0')));
      await tester.tap(find.byKey(const ValueKey('increase-0')));
      await tester.pumpAndSettle();
      expect(
        WeeklyPlan.fromJson(store.rows[dateKey(_week)]!, [mass, other]).checked,
        isEmpty,
      );
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'Adding missing amounts to an existing kg extra ${fail ? 'keeps data on save failure' : 'clears only changed checks and avoids duplicates'}',
      (tester) async {
        final backend = account.AccountBackend();
        backend.documents[account.accountA] = {
          'revision': 1,
          'data': {
            'pantry': [
              {
                'ingredientId': 'salt',
                'name': 'Salz',
                'amount': '1 g',
                'location': 'Trocken',
              },
            ],
            'pantryShoppingItems': [
              {
                'ingredient_id': 'rice',
                'name': 'Reis',
                'quantity': 0.5,
                'unit': 'kg',
              },
              {
                'ingredient_id': 'banana',
                'name': 'Bananen',
                'quantity': 3,
                'unit': 'Stk',
              },
            ],
          },
        };
        final client = (await tester.runAsync(
          () async => backend.client(account.accountA),
        ))!;
        await tester.runAsync(() => account.login(client));
        final rice = _recipe('Reisgericht', const [
          IngredientAmount('rice', 'Reis', 800, 'g'),
        ]);
        final other = _recipe('Salat', const [
          IngredientAmount('oil', 'Öl', 100, 'ml'),
        ]);
        final store = MemoryWeekStore();
        store.rows[dateKey(_week)] = WeeklyPlan(
          meals: {0: PlannedMeal(other, 2)},
          checked: {('rice', 'g'), ('banana', 'Stück')},
        ).toJson();
        await _mount(tester, store, [rice, other], client: client);
        store.fail = fail;
        await _addMissing(tester);
        final data = backend.documents[account.accountA]!['data'] as Map;
        final extras = data['pantryShoppingItems'] as List;
        final saved = WeeklyPlan.fromJson(store.rows[dateKey(_week)]!, [
          rice,
          other,
        ]);
        if (fail) {
          expect(extras.first['quantity'], 0.5);
          expect(extras.first['unit'], 'kg');
          expect(saved.checked, {('rice', 'g'), ('banana', 'Stück')});
        } else {
          expect(
            extras.firstWhere(
              (item) => item['ingredient_id'] == 'rice',
            )['quantity'],
            800,
          );
          expect(
            extras.firstWhere(
              (item) => item['ingredient_id'] == 'rice',
            )['unit'],
            'g',
          );
          expect(saved.checked, {('banana', 'Stück')});
          final calls = store.saveCalls;
          final button = find.descendant(
            of: find.ancestor(
              of: find.text('Reisgericht'),
              matching: find.byType(Card),
            ),
            matching: find.text('Fehlende Zutaten zur Einkaufsliste'),
          );
          await tester.tap(button);
          await account.settleAccount(tester);
          expect(store.saveCalls, calls);
          expect(
            (backend.documents[account.accountA]!['data']
                as Map)['pantryShoppingItems'],
            extras,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Cooking consumes g/ml/piece amounts from kg/l/alias stock using ingredient IDs',
    (tester) async {
      final backend = account.AccountBackend();
      backend.documents[account.accountA] = {
        'revision': 1,
        'data': {
          'pantry': [
            {
              'ingredientId': 'rice',
              'name': 'Langkornreis',
              'amount': '0,5 kg',
              'location': 'Trocken',
            },
            {
              'ingredientId': 'milk',
              'name': 'Milch',
              'amount': '1 L',
              'location': 'Kühlschrank',
            },
            {
              'ingredientId': 'eggs',
              'name': 'Eier',
              'amount': '4 stk.',
              'location': 'Kühlschrank',
            },
          ],
        },
      };
      final client = (await tester.runAsync(
        () async => backend.client(account.accountA),
      ))!;
      await tester.runAsync(() => account.login(client));
      final recipe = _recipe('Auflauf', const [
        IngredientAmount('rice', 'Reis', 200, 'g'),
        IngredientAmount('milk', 'Milch', 250, 'ml'),
        IngredientAmount('eggs', 'Eier', 2, 'Stück'),
      ]);
      final store = MemoryWeekStore();
      store.rows[dateKey(_week)] = WeeklyPlan(
        meals: {DateTime.now().weekday - 1: PlannedMeal(recipe, 2)},
      ).toJson();
      await _mount(tester, store, [recipe], client: client);
      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('week-primary-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kochen starten'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Zubereitung abschließen'),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('200 g verbraucht · Ändern'));
      await reveal(tester, find.text('250 ml verbraucht · Ändern'));
      await reveal(tester, find.text('2 Stück verbraucht · Ändern'));
      await tester.tap(find.widgetWithText(FilledButton, 'Gekocht speichern'));
      await account.settleAccount(tester);
      final stock =
          (backend.documents[account.accountA]!['data'] as Map)['pantry']
              as List;
      expect(
        parseQuantity(
          stock.firstWhere((i) => i['ingredientId'] == 'rice')['amount'],
        ),
        (300, 'g'),
      );
      expect(
        parseQuantity(
          stock.firstWhere((i) => i['ingredientId'] == 'milk')['amount'],
        ),
        (750, 'ml'),
      );
      expect(
        parseQuantity(
          stock.firstWhere((i) => i['ingredientId'] == 'eggs')['amount'],
        ),
        (2, 'Stück'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
