import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/account_data/data/account_data_exporter.dart';
import 'package:kochmaster/features/account_data/data/account_data_management_repository.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

import 'account_household_test.dart'
    show accountA, accountB, householdId, settleAccount;
import 'scroll_helpers.dart';

class _RecordingExporter extends AccountDataExporter {
  Map<String, dynamic>? exported;

  @override
  Future<bool> save(Map<String, dynamic> data, Rect origin) async {
    exported = data;
    return true;
  }
}

class _DataBackend {
  Map<String, dynamic> preferences = {
    'activeHouseholdId': householdId,
    'favoriteRecipes': ['pasta'],
    'pantry': [
      {'name': 'Private stock'},
    ],
  };
  final shared = {
    'pantry': [
      {'name': 'Shared stock', 'amount': '500 g'},
    ],
  };
  final weeks = [
    {
      'week_start': '2026-11-16',
      'meals': ['private-a'],
      'checked': [],
      'revision': 1,
    },
    {
      'week_start': '2026-11-23',
      'meals': ['next-a'],
      'checked': [],
      'revision': 1,
    },
  ];
  int revision = 1;
  final mutations = <String>[];
  String? resetError;
  String? deleteError;
  bool deleted = false;

  late final client = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    httpClient: MockClient((request) async {
      final path = request.url.path.split('/').last;
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(request.body) as Map<String, dynamic>? ?? {});
      http.Response response(Object? data, [int status = 200]) => http.Response(
        jsonEncode(data),
        status,
        request: request,
        headers: {'content-type': 'application/json'},
      );
      if (path == 'token') {
        if (body['password'] != 'test-password') {
          return response({
            'code': 'invalid_credentials',
            'msg': 'Invalid login credentials',
          }, 400);
        }
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
            'user_metadata': {'first_name': 'Test'},
            'created_at': '2026-11-25T00:00:00Z',
          },
        });
      }
      if (path == 'logout') return http.Response('', 204, request: request);
      if (path == 'is_recipe_admin') return response(false);
      if (path == 'user_preferences') {
        return response({'data': preferences, 'revision': revision});
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
        return response({'data': shared, 'revision': 1});
      }
      if (path == 'user_week_plans' || path == 'household_week_plans') {
        return response(null);
      }
      if (path == 'export_my_account_data') {
        return response({
          'format': 'mise-account-export',
          'version': 1,
          'scope': 'personal',
          'profile': {'user_id': accountA, 'email': 'test@example.com'},
          'preferences': preferences,
          'week_plans': weeks,
        });
      }
      if (path == 'reset_my_account_data') {
        if (resetError != null || body['p_revision'] != revision) {
          return response({
            'code': resetError ?? '40001',
            'message': 'conflict',
          }, 409);
        }
        mutations.add(path);
        preferences = {};
        for (final week in weeks) {
          week['meals'] = [];
          week['checked'] = [];
          week['revision'] = (week['revision'] as int) + 1;
        }
        return response(++revision);
      }
      if (path == 'delete_my_account') {
        if (deleteError != null) {
          return response({'code': 'P0001', 'message': deleteError}, 400);
        }
        mutations.add(path);
        deleted = true;
        return http.Response('', 204, request: request);
      }
      if (path.startsWith('save_')) {
        mutations.add(path);
        throw StateError(
          'Data management must not save a blank cloud document: $path',
        );
      }
      throw StateError('Unexpected endpoint $path');
    }),
  );
}

Future<void> _openProfile(
  WidgetTester tester,
  _DataBackend backend, {
  _RecordingExporter? exporter,
}) async {
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
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: PlanningPage(
        recipes: DemoRecipeRepository().getAll(),
        isDemo: false,
        client: backend.client,
        user: backend.client.auth.currentUser,
        store: SupabaseWeeklyPlanRepository(backend.client, accountA),
        dataExporter: exporter ?? const AccountDataExporter(),
      ),
    ),
  );
  await settleAccount(tester);
  await tester.tap(find.byTooltip('Zum Profil'));
  await tester.pumpAndSettle();
}

Future<void> _openAction(WidgetTester tester, String label) async {
  await reveal(tester, find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Guest export preserves recipe snapshots and local removal clears every guest week',
    (tester) async {
      final exporter = _RecordingExporter();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PlanningPage(
            recipes: DemoRecipeRepository().getAll(),
            isDemo: true,
            dataExporter: exporter,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rezepte'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tomaten-Spinat');
      await tester.pumpAndSettle();
      final recipeAction = find.byTooltip(
        'Rezeptaktionen für Tomaten-Spinat-Pasta',
      );
      await reveal(tester, recipeAction);
      await tester.tap(recipeAction);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zum Wochenplan hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Montag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zum Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Meine Cloud-Daten zurücksetzen'), findsNothing);
      expect(find.text('Konto endgültig löschen'), findsNothing);
      await _openAction(tester, 'Meine Daten exportieren');
      await tester.pumpAndSettle();
      final weeks = exporter.exported!['week_plans'] as List;
      expect((weeks.single as Map)['meals'], hasLength(1));
      final meal = ((weeks.single as Map)['meals'] as List).single as Map;
      expect((meal['recipe'] as Map)['name'], 'Tomaten-Spinat-Pasta');
      await _openAction(tester, 'Lokale App-Daten entfernen');
      await tester.tap(find.text('Vom Gerät entfernen'));
      await settleAccount(tester);
      await _openAction(tester, 'Meine Daten exportieren');
      await tester.pumpAndSettle();
      final cleared = exporter.exported!['week_plans'] as List;
      expect(cleared.every((week) => (week['meals'] as List).isEmpty), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Local removal can be cancelled and never resets private or household cloud data',
    (tester) async {
      final backend = _DataBackend();
      final store = SharedPreferencesAsync();
      await store.setString(
        'kochmaster-cooking-progress-$accountA-private',
        'private',
      );
      await store.setString(
        'kochmaster-cooking-progress-$accountA-$householdId',
        'shared',
      );
      await store.setString(
        'kochmaster-cooking-progress-$accountB-private',
        'other-account',
      );
      await _openProfile(tester, backend);
      final original = jsonEncode(backend.preferences);
      await _openAction(tester, 'Lokale App-Daten entfernen');
      expect(
        find.textContaining(
          'Cloud-Daten und sämtliche Haushaltsdaten bleiben erhalten',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(backend.client.auth.currentUser, isNotNull);
      expect(
        await store.getString('kochmaster-cooking-progress-$accountA-private'),
        'private',
      );
      await _openAction(tester, 'Lokale App-Daten entfernen');
      await tester.tap(find.text('Vom Gerät entfernen'));
      await settleAccount(tester);
      expect(backend.mutations, isEmpty);
      expect(jsonEncode(backend.preferences), original);
      expect(backend.shared['pantry'], isNotEmpty);
      expect(backend.client.auth.currentUser, isNull);
      expect(
        await store.getString('kochmaster-cooking-progress-$accountA-private'),
        isNull,
      );
      expect(
        await store.getString(
          'kochmaster-cooking-progress-$accountA-$householdId',
        ),
        isNull,
      );
      expect(
        await store.getString('kochmaster-cooking-progress-$accountB-private'),
        'other-account',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cloud reset requires typed confirmation and preserves the shared household',
    (tester) async {
      final backend = _DataBackend();
      await _openProfile(tester, backend);
      await _openAction(tester, 'Meine Cloud-Daten zurücksetzen');
      final confirm = find.widgetWithText(
        FilledButton,
        'Cloud-Daten zurücksetzen',
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('data-action-phrase')),
        'ZURÜCKSETZEN',
      );
      await tester.pump();
      await tester.tap(confirm);
      await settleAccount(tester);
      expect(backend.mutations, ['reset_my_account_data']);
      expect(backend.preferences, isEmpty);
      expect(
        backend.weeks.every((week) => (week['meals'] as List).isEmpty),
        isTrue,
      );
      expect(backend.shared['pantry'], isNotEmpty);
      expect(backend.client.auth.currentUser, isNotNull);
      expect(find.text('Privat'), findsOneWidget);
      expect(
        find.text('Deine persönlichen Cloud-Daten wurden zurückgesetzt.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A stale cloud reset keeps data and cooking progress and reports the conflict',
    (tester) async {
      final backend = _DataBackend()..resetError = '40001';
      await _openProfile(tester, backend);
      final store = SharedPreferencesAsync();
      await store.setString(
        'kochmaster-cooking-progress-$accountA-private',
        'keep-progress',
      );
      await _openAction(tester, 'Meine Cloud-Daten zurücksetzen');
      await tester.enterText(
        find.byKey(const ValueKey('data-action-phrase')),
        'ZURÜCKSETZEN',
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Cloud-Daten zurücksetzen'),
      );
      await settleAccount(tester);
      expect(backend.mutations, isEmpty);
      expect(backend.preferences['favoriteRecipes'], ['pasta']);
      expect(
        await store.getString('kochmaster-cooking-progress-$accountA-private'),
        'keep-progress',
      );
      expect(find.textContaining('zwischenzeitlich geändert'), findsOneWidget);
      expect(
        find.text('Deine persönlichen Cloud-Daten wurden zurückgesetzt.'),
        findsNothing,
      );
    },
  );

  testWidgets('Wrong password cannot invoke account deletion', (tester) async {
    final backend = _DataBackend();
    await _openProfile(tester, backend);
    await _openAction(tester, 'Konto endgültig löschen');
    final confirm = find.widgetWithText(
      FilledButton,
      'Konto endgültig löschen',
    );
    await tester.enterText(
      find.byKey(const ValueKey('data-action-phrase')),
      'LÖSCHEN',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('data-action-password')),
      'wrong-password',
    );
    await tester.pump();
    await tester.tap(confirm);
    await settleAccount(tester);
    expect(backend.deleted, isFalse);
    expect(backend.mutations, isEmpty);
    expect(backend.client.auth.currentUser, isNotNull);
  });

  testWidgets(
    'Last household admin refusal retains the account and local progress',
    (tester) async {
      final backend = _DataBackend()
        ..deleteError = 'Transfer household administration first';
      await _openProfile(tester, backend);
      final store = SharedPreferencesAsync();
      await store.setString(
        'kochmaster-cooking-progress-$accountA-private',
        'keep-progress',
      );
      await _openAction(tester, 'Konto endgültig löschen');
      await tester.enterText(
        find.byKey(const ValueKey('data-action-phrase')),
        'LÖSCHEN',
      );
      await tester.enterText(
        find.byKey(const ValueKey('data-action-password')),
        'test-password',
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Konto endgültig löschen'),
      );
      await settleAccount(tester);
      expect(backend.deleted, isFalse);
      expect(backend.client.auth.currentUser, isNotNull);
      expect(
        await store.getString('kochmaster-cooking-progress-$accountA-private'),
        'keep-progress',
      );
      expect(find.textContaining('einzige Verwaltung'), findsOneWidget);
    },
  );

  testWidgets(
    'Confirmed account deletion signs out and removes account progress',
    (tester) async {
      final backend = _DataBackend();
      await _openProfile(tester, backend);
      final store = SharedPreferencesAsync();
      await store.setString(
        'kochmaster-cooking-progress-$accountA-private',
        'progress',
      );
      await _openAction(tester, 'Konto endgültig löschen');
      await tester.enterText(
        find.byKey(const ValueKey('data-action-phrase')),
        'LÖSCHEN',
      );
      await tester.enterText(
        find.byKey(const ValueKey('data-action-password')),
        'test-password',
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Konto endgültig löschen'),
      );
      await settleAccount(tester);
      expect(backend.deleted, isTrue);
      expect(backend.mutations, ['delete_my_account']);
      expect(backend.client.auth.currentUser, isNull);
      expect(
        await store.getString('kochmaster-cooking-progress-$accountA-private'),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Export includes all private weeks and no shared stock or session secrets',
    (tester) async {
      final backend = _DataBackend();
      final exporter = _RecordingExporter();
      await _openProfile(tester, backend, exporter: exporter);
      await _openAction(tester, 'Meine Daten exportieren');
      await settleAccount(tester);
      expect(exporter.exported!['scope'], 'personal');
      expect(exporter.exported!['week_plans'], hasLength(2));
      final exportedText = jsonEncode(exporter.exported);
      expect(exportedText, contains('Private stock'));
      expect(exportedText, isNot(contains('Shared stock')));
      expect(exportedText, isNot(contains('refresh_token')));
      expect(exportedText, isNot(contains('access_token')));
      expect(backend.mutations, isEmpty);
    },
  );

  test(
    'Repository never sends an account ID to data-management operations',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.url.path.endsWith('export_my_account_data') ? '{}' : '1',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = AccountDataManagementRepository(client);
      await repository.exportData();
      await repository.resetPersonalData(7);
      await repository.deleteAccount();
      expect(jsonDecode(requests[1].body), {'p_revision': 7});
      expect(
        requests.every((request) => !request.body.contains('user_id')),
        isTrue,
      );
    },
  );
}
