import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/app/kochmaster_app.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';

void main() {
  testWidgets(
    'Token-Erneuerung, neuer Client und Versionskonflikt erhalten den Wochenplan',
    (tester) async {
      await tester.runAsync(() async {
        const id = '11111111-1111-4111-8111-111111111111';
        final recipes = DemoRecipeRepository().getAll();
        var row = <String, dynamic>{
          'meals': [
            {
              'day': DateTime.now().weekday - 1,
              'recipe_id': recipes.first.id,
              'recipe': recipeSnapshot(recipes.first),
              'servings': 4,
            },
          ],
          'checked': <dynamic>[],
          'revision': 4,
        };
        var preferenceRevision = 0;
        Map<String, dynamic> preferences = {};
        final clients = <SupabaseClient>[];
        SupabaseClient client() {
          final transport = MockClient((request) async {
            http.Response response(Object? value, [int status = 200]) =>
                http.Response(
                  jsonEncode(value),
                  status,
                  request: request,
                  headers: {'content-type': 'application/json'},
                );
            final path = request.url.path.split('/').last;
            final body = request.body.isEmpty
                ? <String, dynamic>{}
                : (jsonDecode(request.body) ?? <String, dynamic>{})
                      as Map<String, dynamic>;
            if (path == 'token') {
              final exp =
                  DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000;
              String part(Object value) => base64Url
                  .encode(utf8.encode(jsonEncode(value)))
                  .replaceAll('=', '');
              return response({
                'access_token':
                    '${part({'alg': 'HS256'})}.${part({'sub': id, 'exp': exp})}.signature',
                'refresh_token': 'test-refresh',
                'expires_in': 3600,
                'expires_at': exp,
                'token_type': 'bearer',
                'user': {
                  'id': id,
                  'aud': 'authenticated',
                  'email': 'test@example.com',
                  'app_metadata': {},
                  'user_metadata': {},
                  'created_at': '2026-11-19T10:00:00Z',
                },
              });
            }
            if (path == 'is_recipe_admin') return response(false);
            if (path == 'user_preferences') {
              return response({
                'data': preferences,
                'revision': preferenceRevision,
              });
            }
            if (path == 'household_dashboard') return response([]);
            if (path == 'save_user_preferences') {
              if (body['p_revision'] != preferenceRevision) {
                return response({'code': '40001', 'message': 'conflict'}, 409);
              }
              preferences = Map<String, dynamic>.from(body['p_data'] as Map);
              return response(++preferenceRevision);
            }
            if (path == 'user_week_plans') return response(row);
            if (path == 'save_user_week_plan') {
              expect(body['p_user'], id);
              if (body['p_revision'] != row['revision']) {
                return response({'code': '40001', 'message': 'conflict'}, 409);
              }
              row = {
                'meals': body['p_meals'],
                'checked': body['p_checked'],
                'revision': (row['revision'] as int) + 1,
              };
              return response(row['revision']);
            }
            throw StateError('Unexpected endpoint $path');
          });
          final result = SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            httpClient: transport,
          );
          clients.add(result);
          return result;
        }

        Future<void> show(SupabaseClient client) async {
          await tester.pumpWidget(
            KochmasterApp(client: client, repository: DemoRecipeRepository()),
          );
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            await tester.pump();
          }
          await tester.pumpAndSettle();
        }

        Future<void> shopping() async {
          expect(
            find.text('Korb'),
            findsOneWidget,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data)
                .join(' | '),
          );
          await tester.tap(find.text('Korb'));
          await tester.pumpAndSettle();
          if (find.text('Selbst einkaufen').evaluate().isNotEmpty) {
            await tester.tap(find.text('Selbst einkaufen').last);
            await tester.pumpAndSettle();
          }
        }

        final first = client();
        final second = client();
        try {
          await first.auth.signInWithPassword(
            email: 'test@example.com',
            password: 'test-password',
          );
          await show(first);
          final originalStore = tester
              .widget<PlanningPage>(find.byType(PlanningPage))
              .store!;
          await first.auth.refreshSession();
          await Future<void>.delayed(Duration.zero);
          await tester.pumpAndSettle();
          expect(
            tester.widget<PlanningPage>(find.byType(PlanningPage)).store,
            same(originalStore),
          );
          await shopping();
          final tomato = find.widgetWithText(CheckboxListTile, 'Tomaten');
          await tester.ensureVisible(tomato);
          await tester.pumpAndSettle();
          await tester.tap(tomato);
          await tester.pumpAndSettle();
          expect(row['revision'], 5);
          expect(row['checked'], isNotEmpty);
          await tester.pumpWidget(const SizedBox());

          await second.auth.signInWithPassword(
            email: 'test@example.com',
            password: 'test-password',
          );
          await show(second);
          await shopping();
          await tester.ensureVisible(tomato);
          await tester.pumpAndSettle();
          expect(tester.widget<CheckboxListTile>(tomato).value, isTrue);
          expect((row['meals'] as List).single['servings'], 4);
          await tester.tap(tomato);
          await tester.pumpAndSettle();
          expect(row['revision'], 6);
          await expectLater(
            originalStore.save(mondayOf(DateTime.now()), WeeklyPlan()),
            throwsA(
              isA<PostgrestException>().having(
                (error) => error.code,
                'code',
                '40001',
              ),
            ),
          );
          expect((row['meals'] as List).single['servings'], 4);
          expect(row['checked'], isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          for (final value in clients) {
            await value.dispose();
          }
        }
      });
    },
  );
}
