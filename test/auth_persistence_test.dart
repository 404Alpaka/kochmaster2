import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

void main() {
  test('Login, Wochenplan speichern und neu laden, Fehler und Abmelden', () async {
    const userId = '3c1fa0a8-b0e0-4aa3-9bb1-1c46d93ced52';
    final expiry =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': userId, 'exp': expiry, 'aud': 'authenticated'})}.test-signature';
    Map<String, dynamic>? saved;
    bool fail = false;
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/token')) {
        return http.Response(
          jsonEncode({
            'access_token': token,
            'token_type': 'bearer',
            'expires_in': 3600,
            'expires_at': expiry,
            'refresh_token': 'test-refresh',
            'user': {
              'id': userId,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'test@example.com',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-11-16T12:00:00Z',
            },
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/logout')) {
        return http.Response('', 204, request: request);
      }
      if (request.url.path.endsWith('/user_week_plans')) {
        expect(request.headers['Authorization'], 'Bearer $token');
        if (fail) {
          return http.Response(
            '{"message":"Unavailable"}',
            503,
            request: request,
          );
        }
        if (request.method == 'POST') {
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          expect(saved!['user_id'], userId);
          expect(saved!['week_start'], '2026-11-16');
          return http.Response('', 201, request: request);
        }
        expect(request.url.queryParameters['user_id'], 'eq.$userId');
        return http.Response(
          jsonEncode(
            saved == null
                ? null
                : {'meals': saved!['meals'], 'checked': saved!['checked']},
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected endpoint: ${request.url.path}');
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: transport,
    );
    try {
      await client.auth.signInWithPassword(
        email: 'test@example.com',
        password: 'test-password',
      );
      expect(client.auth.currentUser!.id, userId);
      final store = SupabaseWeeklyPlanRepository(client, userId);
      final recipes = DemoRecipeRepository().getAll();
      final week = DateTime(2026, 11, 16);
      final plan = WeeklyPlan(
        meals: {0: PlannedMeal(recipes[0], 4)},
        checked: {('tomato', 'g')},
      );
      await store.save(week, plan);
      final restored = await store.load(week, recipes);
      expect(restored.meals[0]!.servings, 4);
      expect(restored.checked, {('tomato', 'g')});
      fail = true;
      await expectLater(
        store.save(week, plan),
        throwsA(isA<PostgrestException>()),
      );
      await client.auth.signOut();
      expect(client.auth.currentUser, isNull);
      await expectLater(store.save(week, plan), throwsStateError);
    } finally {
      await client.dispose();
      transport.close();
    }
  });
}
