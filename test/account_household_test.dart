import 'dart:convert';

import 'scroll_helpers.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/account_data/data/account_data_repository.dart';
import 'package:kochmaster/features/households/data/household_repository.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

const accountA = '11111111-1111-4111-8111-111111111111';
const accountB = '22222222-2222-4222-8222-222222222222';
const householdId = '33333333-3333-4333-8333-333333333333';

class AccountBackend {
  final documents = <String, Map<String, dynamic>>{};
  final writes = <Map<String, dynamic>>[];
  String role = 'editor';
  bool missing = false;
  bool offline = false;
  int stateRevision = 0;
  Map<String, dynamic> shared = {'pantry': <dynamic>[]};
  Map<String, dynamic> sharedWeek = {
    'meals': <dynamic>[],
    'checked': <dynamic>[],
    'revision': 0,
  };
  SupabaseClient client(String id) {
    final transport = MockClient((request) async {
      http.Response response(Object? value, [int code = 200]) => http.Response(
        jsonEncode(value),
        code,
        request: request,
        headers: {'content-type': 'application/json'},
      );
      final path = request.url.path.split('/').last;

      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(request.body) as Map<String, dynamic>? ??
                <String, dynamic>{});
      if (path == 'token') {
        final expires =
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        String part(Object value) => base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
        final token =
            '${part({'alg': 'HS256'})}.${part({'sub': id, 'exp': expires, 'aud': 'authenticated'})}.signature';
        return response({
          'access_token': token,
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at': expires,
          'refresh_token': 'refresh',
          'user': {
            'id': id,
            'aud': 'authenticated',
            'email': '$id@example.com',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-11-17T12:00:00Z',
          },
        });
      }
      if (path == 'logout') return http.Response('', 204, request: request);
      if (path == 'is_recipe_admin') return response(false);
      if (offline) throw http.ClientException('offline');
      if (missing)
        return response({
          'code': '42P01',
          'message': 'table does not exist',
        }, 404);
      if (path == 'user_preferences') {
        expect(request.url.queryParameters['user_id'], 'eq.$id');
        return response(documents[id]);
      }
      if (path == 'save_user_preferences') {
        expect(body['p_user'], id);
        final old = documents[id];
        if (body['p_revision'] != (old?['revision'] ?? 0))
          return response({'code': '40001', 'message': 'conflict'}, 409);
        final revision = (old?['revision'] as int? ?? 0) + 1;
        documents[id] = {
          'data': jsonDecode(jsonEncode(body['p_data'])),
          'revision': revision,
        };
        writes.add({'kind': 'private', 'user': id, ...body});
        return response(revision);
      }
      if (path == 'household_dashboard')
        return response([
          {
            'id': householdId,
            'name': 'Familie Test',
            'role': role,
            'members': [
              {'user_id': id, 'email': '$id@example.com', 'role': role},
            ],
            'invitations': <dynamic>[],
          },
        ]);
      if (path == 'household_state')
        return response({'data': shared, 'revision': stateRevision});
      if (path == 'save_household_state') {
        if (role == 'viewer')
          return response({'code': '42501', 'message': 'denied'}, 403);
        if (body['p_revision'] != stateRevision)
          return response({'code': '40001', 'message': 'conflict'}, 409);
        shared = Map<String, dynamic>.from(body['p_data'] as Map);
        writes.add({'kind': 'shared', ...body});
        return response(++stateRevision);
      }
      if (path == 'household_week_plans') return response(sharedWeek);
      if (path == 'save_household_week') {
        if (role == 'viewer')
          return response({'code': '42501', 'message': 'denied'}, 403);
        if (body['p_revision'] != sharedWeek['revision'])
          return response({'code': '40001', 'message': 'conflict'}, 409);
        sharedWeek = {
          'meals': body['p_meals'],
          'checked': body['p_checked'],
          'revision': (sharedWeek['revision'] as int) + 1,
        };
        writes.add({'kind': 'week', ...body});
        return response(sharedWeek['revision']);
      }
      if (path == 'user_week_plans') return response(null);
      throw StateError('Unexpected endpoint $path');
    });
    return SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: transport,
    );
  }
}

Future<void> login(SupabaseClient client) async {
  await client.auth.signInWithPassword(
    email: 'test@example.com',
    password: 'test-password',
  );
}

Widget planning(SupabaseClient client) => MaterialApp(
  theme: AppTheme.light,
  home: PlanningPage(
    key: ValueKey(client),
    recipes: DemoRecipeRepository().getAll(),
    isDemo: false,
    client: client,
    user: client.auth.currentUser,
    store: SupabaseWeeklyPlanRepository(client, client.auth.currentUser!.id),
  ),
);

Future<void> settleAccount(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Private data survives another client and uses revision conflicts',
    () async {
      final backend = AccountBackend();
      final first = backend.client(accountA);
      final second = backend.client(accountA);
      final other = backend.client(accountB);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(other.dispose);
      await login(first);
      await login(second);
      await login(other);
      final a = AccountDataRepository(first, accountA);
      final b = AccountDataRepository(second, accountA);
      expect(await a.load(), isNull);
      expect(
        await a.save({
          'favoriteRecipes': ['pasta'],
          'personalExclusions': ['Soja'],
        }, 0),
        1,
      );
      final restored = (await b.load())!;
      expect(restored.data['personalExclusions'], ['Soja']);
      await a.save({
        'favoriteRecipes': ['rice'],
      }, restored.revision);
      await expectLater(
        b.save({'favoriteRecipes': []}, restored.revision),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '40001'),
        ),
      );
      expect(await AccountDataRepository(other, accountB).load(), isNull);
    },
  );
  test('Shared scope never copies private recipes, favorites or allergies', () {
    final personal = {
      'pantry': [
        {'name': 'Private stock'},
      ],
      'favoriteRecipes': ['pasta'],
      'personalRecipes': [
        {'secret': 'recipe'},
      ],
      'personalExclusions': ['Soja'],
      'household': 'Privat',
    };
    final current = {
      ...personal,
      'pantry': [
        {'name': 'Shared stock'},
      ],
      'household': 'Familie',
    };
    final shared = sharedAccountData(current);
    expect(shared.keys, isNot(contains('personalExclusions')));
    expect(shared.keys, isNot(contains('personalRecipes')));
    expect(shared.keys, isNot(contains('favoriteRecipes')));
    final private = privateAccountData(
      current,
      personal,
      householdActive: true,
    );
    expect(private['pantry'], personal['pantry']);
    expect(private['household'], 'Privat');
  });
  test('Shared week persists snapshots and checked items and rejects stale versions', () async {
    final backend = AccountBackend();
    final client = backend.client(accountA);
    addTearDown(client.dispose);
    await login(client);
    final first = HouseholdWeeklyPlanRepository(client, householdId);
    final second = HouseholdWeeklyPlanRepository(client, householdId);
    final week = DateTime(2026, 11, 16);
    final recipes = DemoRecipeRepository().getAll();
    await first.load(week, recipes);
    await second.load(week, recipes);
    await first.save(
      week,
      WeeklyPlan(
        meals: {0: PlannedMeal(recipes.first, 4)},
        checked: {('pasta', 'g')},
      ),
    );
    final restored = await first.load(week, []);
    expect(restored.meals[0]!.servings, 4);
    expect(restored.checked, {('pasta', 'g')});
    await expectLater(
      second.save(week, WeeklyPlan()),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '40001')),
    );
  });
  testWidgets(
    'Connected household shows real members and switching preserves private data',
    (tester) async {
      final backend = AccountBackend();
      backend.documents[accountA] = {
        'revision': 1,
        'data': {
          'favoriteRecipes': ['pasta'],
          'personalExclusions': ['Soja'],
          'pantry': [
            {'name': 'Private stock'},
          ],
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

      expect(
        find.byTooltip('Zum Profil'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zum Profil'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Alex'), findsNothing);
      await tester.tap(find.text('Gemeinsam'));
      await settleAccount(tester);
      await reveal(tester, find.text('Deine Rolle: Mitglied'));
      expect(find.text('Deine Rolle: Mitglied'), findsOneWidget);
      await reveal(tester, find.text('Haushalt verwalten'));
      await tester.tap(find.text('Haushalt verwalten'));
      await tester.pumpAndSettle();
      expect(find.text('Zusammen isst’s besser.'), findsOneWidget);
      await tester.tap(find.text('Zurück zum Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Profil'), findsOneWidget);
      expect(backend.documents[accountA]!['data']['pantry'], [
        {'name': 'Private stock'},
      ]);
      expect(backend.documents[accountA]!['data']['personalExclusions'], [
        'Soja',
      ]);
      expect(backend.shared.keys, isNot(contains('personalExclusions')));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Viewer reads shared plans and never sees demo members or editing actions',
    (tester) async {
      final backend = AccountBackend()..role = 'viewer';
      backend.documents[accountA] = {
        'revision': 1,
        'data': {'activeHouseholdId': householdId},
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
      expect(find.text('Nur ansehen'), findsOneWidget);
      expect(find.text('Wochenplan erstellen'), findsNothing);
      expect(
        find.byTooltip('Zum Profil'),
        findsNothing,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zum Profil'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Deine Rolle: Nur ansehen'));
      expect(find.text('Deine Rolle: Nur ansehen'), findsOneWidget);
      await reveal(tester, find.text('Haushalt verwalten'));
      await tester.tap(find.text('Haushalt verwalten'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Alex'), findsNothing);
      expect(find.text('Person einladen'), findsNothing);
      expect(backend.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Missing migration gives a concrete error and does not overwrite local data',
    (tester) async {
      final backend = AccountBackend()..missing = true;
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

      expect(
        find.textContaining('202611170003_account_data_and_households.sql'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      expect(backend.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
