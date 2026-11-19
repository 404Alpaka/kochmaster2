import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';

void main() {
  test(
    'Parallele Pläne und Erstschreibzugriffe benötigen die geladene Revision',
    () async {
      const userId = '12345678-1234-4234-8234-123456789012';
      final rows = <String, Map<String, dynamic>>{};
      final transport = MockClient((request) async {
        http.Response response(Object? body, [int status = 200]) =>
            http.Response(
              jsonEncode(body),
              status,
              request: request,
              headers: {'content-type': 'application/json'},
            );
        if (request.url.path.endsWith('/token')) {
          return response({
            'access_token': 'test-token',
            'refresh_token': 'refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': userId,
              'aud': 'authenticated',
              'email': 'test@example.com',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-11-18T12:00:00Z',
            },
          });
        }
        if (request.method == 'GET') {
          final key = request.url.queryParameters['week_start']!.substring(3);
          return response(rows[key]);
        }
        expect(request.url.path, '/rest/v1/rpc/save_user_week_plan');
        final body = jsonDecode(request.body) as Map;
        final key = body['p_week'] as String;
        final revision = rows[key]?['revision'] ?? 0;
        if (body['p_revision'] != revision) {
          return response({'code': '40001', 'message': 'conflict'}, 409);
        }
        rows[key] = {
          'meals': body['p_meals'],
          'checked': body['p_checked'],
          'revision': revision + 1,
        };
        return response(revision + 1);
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
        final first = SupabaseWeeklyPlanRepository(client, userId);
        final second = SupabaseWeeklyPlanRepository(client, userId);
        final week = DateTime(2026, 11, 16);
        final nextWeek = DateTime(2026, 11, 23);
        final bought = WeeklyPlan(checked: {('tomato', 'g')});
        await expectLater(first.save(week, bought), throwsStateError);
        await first.load(week, []);
        await second.load(week, []);
        await first.save(week, bought);
        final conflict = isA<PostgrestException>().having(
          (e) => e.code,
          'code',
          '40001',
        );
        await expectLater(second.save(week, WeeklyPlan()), throwsA(conflict));
        await expectLater(second.save(week, WeeklyPlan()), throwsA(conflict));
        expect((await first.load(week, [])).checked, bought.checked);
        await second.load(week, []);
        await second.save(week, WeeklyPlan());
        await expectLater(first.save(week, bought), throwsA(conflict));
        await first.load(nextWeek, []);
        await first.save(nextWeek, bought);
        expect(rows[dateKey(week)]!['revision'], 2);
        expect(rows[dateKey(nextWeek)]!['revision'], 1);
      } finally {
        await client.dispose();
        transport.close();
      }
    },
  );
}
