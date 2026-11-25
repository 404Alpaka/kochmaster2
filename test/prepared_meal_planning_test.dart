import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/features/shopping/domain/build_shopping_list.dart';

import 'account_household_test.dart' show accountA, householdId, settleAccount;
import 'scroll_helpers.dart';

final _recipes = DemoRecipeRepository().getAll();
final _sourceWeek = mondayOf(DateTime.now());
final _nextWeek = DateTime(
  _sourceWeek.year,
  _sourceWeek.month,
  _sourceWeek.day + 7,
);
final _keptIngredient = _recipes.last.ingredients.firstWhere(
  (ingredient) => !_recipes.first.ingredients.any(
    (other) => other.ingredientId == ingredient.ingredientId,
  ),
);

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

Map<String, dynamic> _leftovers(String id, String name) => {
  'id': id,
  'name': name,
  'portions': 6,
  'location': 'Gefrierfach',
  'cookedOn': dateKey(_sourceWeek),
  'storedOn': dateKey(_sourceWeek),
  'reservations': <String, dynamic>{},
  'recipe': recipeSnapshot(
    Recipe(
      id: id,
      name: name,
      minutes: 20,
      servings: 2,
      ingredients: const [
        IngredientAmount('prepared-tomato', 'Tomaten', 300, 'g'),
      ],
      steps: const ['Zubereiten.'],
    ),
  ),
};

class _PreparedBackend {
  _PreparedBackend({this.sharedActive = true}) {
    preferences = {
      if (sharedActive) 'activeHouseholdId': householdId,
      'preparedMeals': [_leftovers('private-leftovers', 'Private Suppe')],
    };
    for (final weeks in [privateWeeks, sharedWeeks]) {
      weeks[dateKey(_sourceWeek)] = {
        ...WeeklyPlan(meals: {2: PlannedMeal(_recipes.last, 2)}).toJson(),
        'revision': 2,
      };
      weeks[dateKey(_nextWeek)] = {
        ...WeeklyPlan(
          meals: {
            0: PlannedMeal(
              weeks == sharedWeeks ? _recipes.first : _recipes.last,
              2,
            ),
            4: PlannedMeal(_recipes.last, 2),
          },
          checked: {(_keptIngredient.ingredientId, _keptIngredient.unit)},
        ).toJson(),
        'revision': 3,
      };
    }
  }

  final bool sharedActive;
  late Map<String, dynamic> preferences;
  Map<String, dynamic> shared = {
    'preparedMeals': [_leftovers('shared-leftovers', 'Gemeinsame Lasagne')],
  };
  int personalRevision = 1;
  int sharedRevision = 1;
  final privateWeeks = <String, Map<String, dynamic>>{};
  final sharedWeeks = <String, Map<String, dynamic>>{};
  final weekReads = <(String, String)>[];
  final weekWrites = <Map<String, dynamic>>[];
  String? failingLoad;
  String? saveError;
  Completer<void>? loadingTarget;

  List<dynamic> get activeMeals =>
      (sharedActive ? shared : preferences)['preparedMeals'] as List;

  late final client = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    httpClient: MockClient((request) async {
      final path = request.url.path.split('/').last;
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>? ?? {};
      http.Response response(Object? value, [int status = 200]) =>
          http.Response(
            jsonEncode(value),
            status,
            request: request,
            headers: {'content-type': 'application/json'},
          );
      if (path == 'token') {
        final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        String part(Object value) => base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
        return response({
          'access_token':
              '${part({'alg': 'HS256'})}.${part({'sub': accountA, 'exp': expires, 'aud': 'authenticated'})}.signature',
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at': expires,
          'refresh_token': 'refresh',
          'user': {
            'id': accountA,
            'aud': 'authenticated',
            'email': 'test@example.com',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-11-25T00:00:00Z',
          },
        });
      }
      if (path == 'is_recipe_admin') return response(false);
      if (path == 'user_preferences') {
        return response({'data': preferences, 'revision': personalRevision});
      }
      if (path == 'household_dashboard') {
        return response([
          {
            'id': householdId,
            'name': 'Familie Test',
            'role': 'editor',
            'members': [],
            'invitations': [],
          },
        ]);
      }
      if (path == 'household_state') {
        return response({'data': shared, 'revision': sharedRevision});
      }
      if (path == 'save_user_preferences') {
        expect(body['p_revision'], personalRevision);
        preferences = _copy(body['p_data'] as Map<String, dynamic>);
        return response(++personalRevision);
      }
      if (path == 'save_household_state') {
        expect(body['p_household'], householdId);
        expect(body['p_revision'], sharedRevision);
        shared = _copy(body['p_data'] as Map<String, dynamic>);
        return response(++sharedRevision);
      }
      if (path == 'user_week_plans' || path == 'household_week_plans') {
        final key = request.url.queryParameters['week_start']!.substring(3);
        weekReads.add((path, key));
        if (key == failingLoad) {
          return response({'code': 'XX000', 'message': 'offline'}, 500);
        }
        if (key == dateKey(_nextWeek)) await loadingTarget?.future;
        final weeks = path == 'household_week_plans'
            ? sharedWeeks
            : privateWeeks;
        return response(weeks[key]);
      }
      if (path == 'save_user_week_plan' || path == 'save_household_week') {
        if (saveError != null) {
          return response({'code': saveError, 'message': 'conflict'}, 409);
        }
        final weeks = path == 'save_household_week'
            ? sharedWeeks
            : privateWeeks;
        final key = body['p_week'] as String;
        final revision = (weeks[key]?['revision'] as int? ?? 0);
        expect(body['p_revision'], revision);
        weekWrites.add({'path': path, ...body});
        weeks[key] = _copy({
          'meals': body['p_meals'],
          'checked': body['p_checked'],
          'revision': revision + 1,
        });
        return response(revision + 1);
      }
      throw StateError('Unexpected request $path');
    }),
  );
}

Future<void> _openRestPlanning(
  WidgetTester tester,
  _PreparedBackend backend, {
  bool reopening = false,
}) async {
  if (!reopening) {
    tester.view.physicalSize = const Size(390, 964);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => backend.client.auth.signInWithPassword(
        email: 'test@example.com',
        password: 'test-password',
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(backend.client.dispose);
    });
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: PlanningPage(
        recipes: _recipes,
        isDemo: false,
        client: backend.client,
        user: backend.client.auth.currentUser,
        store: SupabaseWeeklyPlanRepository(backend.client, accountA),
      ),
    ),
  );
  await settleAccount(tester);
  await tester.tap(find.text('Vorrat').last);
  await tester.pumpAndSettle();
  final mealName = backend.sharedActive
      ? 'Gemeinsame Lasagne'
      : 'Private Suppe';
  await reveal(tester, find.text(mealName));
  await tester.tap(find.text(mealName));
  await settleAccount(tester);
  await reveal(tester, find.text('Erneut einplanen'));
  await tester.tap(find.text('Erneut einplanen'));
  await tester.pumpAndSettle();
}

Future<void> _chooseDay(WidgetTester tester, DateTime date) async {
  const weekdays = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  final choice = find.textContaining(
    '${weekdays[date.weekday - 1]}, ${date.day}.${date.month}.${date.year}',
  );
  await reveal(tester, choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

Future<void> _submit(
  WidgetTester tester, {
  String day = 'Montag',
  bool replace = true,
}) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Für $day einplanen'));
  await settleAccount(tester);
  if (replace) {
    expect(find.text('Geplantes Gericht ersetzen?'), findsOneWidget);
    await tester.tap(find.text('Ersetzen'));
    await settleAccount(tester);
  }
}

void main() {
  testWidgets(
    'Next-week leftovers use the household plan, preserve other meals/checks and survive reopening',
    (tester) async {
      final backend = _PreparedBackend();
      final privateBefore = jsonEncode(backend.privateWeeks);
      final sourceBefore = jsonEncode(
        backend.sharedWeeks[dateKey(_sourceWeek)],
      );
      await _openRestPlanning(tester, backend);
      await _chooseDay(tester, _nextWeek);
      await _submit(tester);
      expect(backend.weekWrites.single['path'], 'save_household_week');
      expect(backend.weekWrites.single['p_household'], householdId);
      expect(backend.weekWrites.single['p_week'], dateKey(_nextWeek));
      expect(jsonEncode(backend.privateWeeks), privateBefore);
      expect(
        jsonEncode(backend.sharedWeeks[dateKey(_sourceWeek)]),
        sourceBefore,
      );
      final target = WeeklyPlan.fromJson(
        backend.sharedWeeks[dateKey(_nextWeek)]!,
        _recipes,
      );
      expect(target.meals[0]!.preparedMealId, 'shared-leftovers');
      expect(target.meals[0]!.servings, 2);
      expect(target.meals[4]!.recipe.id, _recipes.last.id);
      expect(
        target.checked,
        contains((_keptIngredient.ingredientId, _keptIngredient.unit)),
      );
      expect(
        buildShoppingList(target.meals.values)
            .any((i) => i.ingredientId == 'prepared-tomato'),
        isFalse,
      );
      expect((backend.shared['preparedMeals'] as List).single['reservations'], {
        dateKey(_nextWeek): 2,
      });
      expect((backend.shared['preparedMeals'] as List).single['portions'], 6);
      expect(
        (backend.preferences['preparedMeals'] as List).single['reservations'],
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await _openRestPlanning(tester, backend, reopening: true);
      expect(
        find.textContaining('4 Portionen für diesen Tag verfügbar'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancelling replacement leaves both plans and reservations untouched',
    (tester) async {
      final backend = _PreparedBackend();
      await _openRestPlanning(tester, backend);
      final sharedBefore = jsonEncode(backend.sharedWeeks);
      final privateBefore = jsonEncode(backend.privateWeeks);
      final portionsBefore = jsonEncode(backend.activeMeals);
      await _chooseDay(tester, _nextWeek);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Für Montag einplanen'),
      );
      await settleAccount(tester);
      expect(
        find.textContaining(
          '${_recipes.first.name} wird durch Gemeinsame Lasagne ersetzt.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Abbrechen'));
      await settleAccount(tester);
      expect(backend.weekWrites, isEmpty);
      expect(jsonEncode(backend.sharedWeeks), sharedBefore);
      expect(jsonEncode(backend.privateWeeks), privateBefore);
      expect(jsonEncode(backend.activeMeals), portionsBefore);
      expect(
        find.widgetWithText(FilledButton, 'Für Montag einplanen'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Private leftovers still use the private plan without changing shared data',
    (tester) async {
      final backend = _PreparedBackend(sharedActive: false);
      final sharedBefore = jsonEncode(backend.sharedWeeks);
      await _openRestPlanning(tester, backend);
      await _chooseDay(tester, _nextWeek);
      await _submit(tester);
      expect(backend.weekWrites.single['path'], 'save_user_week_plan');
      expect(backend.weekWrites.single['p_user'], accountA);
      expect(jsonEncode(backend.sharedWeeks), sharedBefore);
      expect(
        (backend.preferences['preparedMeals'] as List).single['reservations'],
        {dateKey(_nextWeek): 2},
      );
      expect(
        (backend.shared['preparedMeals'] as List).single['reservations'],
        isEmpty,
      );
    },
  );

  testWidgets('Failed target load preserves the source week and stock', (
    tester,
  ) async {
    final backend = _PreparedBackend();
    await _openRestPlanning(tester, backend);
    final before = jsonEncode(backend.sharedWeeks);
    backend.failingLoad = dateKey(_nextWeek);
    await _chooseDay(tester, _nextWeek);
    await _submit(tester, replace: false);
    expect(backend.weekWrites, isEmpty);
    expect(jsonEncode(backend.sharedWeeks), before);
    expect((backend.activeMeals.single as Map)['reservations'], isEmpty);
    await reveal(
      tester,
      find.text(
        'Zielwoche konnte nicht geladen werden. Bitte erneut versuchen.',
      ),
    );
    expect(
      find.widgetWithText(FilledButton, 'Für Montag einplanen'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Version conflict preserves stock and retry reloads the changed target week',
    (tester) async {
      final backend = _PreparedBackend();
      await _openRestPlanning(tester, backend);
      final before = jsonEncode(backend.sharedWeeks);
      backend.saveError = '40001';
      await _chooseDay(tester, _nextWeek);
      await _submit(tester);
      expect(jsonEncode(backend.sharedWeeks), before);
      expect(backend.weekWrites, isEmpty);
      expect((backend.activeMeals.single as Map)['reservations'], isEmpty);
      await reveal(
        tester,
        find.textContaining(
          'Die Zielwoche wurde auf einem anderen Gerät geändert.',
        ),
      );
      final changed = WeeklyPlan.fromJson(
        backend.sharedWeeks[dateKey(_nextWeek)]!,
        _recipes,
      );
      changed.meals[3] = PlannedMeal(_recipes.first, 3);
      backend.sharedWeeks[dateKey(_nextWeek)] = {
        ...changed.toJson(),
        'revision': 4,
      };
      backend.saveError = null;
      await _submit(tester);
      expect(
        backend.weekReads.where(
          (read) => read == ('household_week_plans', dateKey(_nextWeek)),
        ),
        hasLength(2),
      );
      final saved = WeeklyPlan.fromJson(
        backend.sharedWeeks[dateKey(_nextWeek)]!,
        _recipes,
      );
      expect(saved.meals[3]!.servings, 3);
      expect(saved.meals[0]!.preparedMealId, 'shared-leftovers');
    },
  );

  testWidgets('Navigation is blocked while the target week is loading', (
    tester,
  ) async {
    final backend = _PreparedBackend();
    await _openRestPlanning(tester, backend);
    final target = DateTime(_nextWeek.year, _nextWeek.month, _nextWeek.day + 1);
    await _chooseDay(tester, target);
    final pending = Completer<void>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete();
    });
    backend.loadingTarget = pending;
    await tester.tap(
      find.widgetWithText(FilledButton, 'Für Dienstag einplanen'),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await tester.tap(find.text('Start').last, warnIfMissed: false);
    await tester.binding.handlePopRoute();
    await tester.pump();
    final action = find.widgetWithText(FilledButton, 'Für Dienstag einplanen');
    expect(action, findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    expect(backend.weekWrites, isEmpty);
    pending.complete();
    await settleAccount(tester);
    expect(backend.weekWrites.single['path'], 'save_household_week');
    final saved = WeeklyPlan.fromJson(
      backend.sharedWeeks[dateKey(_nextWeek)]!,
      _recipes,
    );
    expect(saved.meals[1]!.preparedMealId, 'shared-leftovers');
    expect(tester.takeException(), isNull);
  });
}
