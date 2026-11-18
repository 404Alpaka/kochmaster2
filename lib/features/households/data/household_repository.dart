import 'package:supabase/supabase.dart';

import '../../account_data/data/account_data_repository.dart';
import '../../meal_planning/data/weekly_plan_repository.dart';
import '../../recipes/domain/recipe.dart';

class ConnectedHousehold {
  ConnectedHousehold.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      name = row['name'] as String,
      role = row['role'] as String,
      members = (row['members'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList(),
      invitations = (row['invitations'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
  final String id;
  final String name;
  final String role;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> invitations;
  bool get canEdit => role != 'viewer';
  bool get isAdmin => role == 'admin';
}

String householdRoleLabel(String role) => switch (role) {
  'admin' => 'Verwaltung',
  'editor' => 'Mitglied',
  _ => 'Nur ansehen',
};

class HouseholdRepository {
  HouseholdRepository(this.client);
  final SupabaseClient client;
  Future<dynamic> call(String name, [Map<String, dynamic>? params]) =>
      client.rpc(name, params: params).timeout(const Duration(seconds: 20));
  Future<List<ConnectedHousehold>> list() async =>
      ((await call('household_dashboard')) as List)
          .map(
            (r) => ConnectedHousehold.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
  Future<String> create(String name) async =>
      await call('create_household', {'p_name': name}) as String;
  Future<String> invite(String id, String email, String role) async =>
      await call('invite_household', {
        'p_household': id,
        'p_email': email,
        'p_role': role,
      }) as String;
  Future<String> accept(String token) async =>
      await call('accept_household_invitation', {'p_token': token}) as String;
  Future<void> revoke(String id) async {
    await call('revoke_household_invitation', {'p_id': id});
  }

  Future<void> changeRole(String id, String user, String role) async {
    await call('change_household_role', {
      'p_household': id,
      'p_user': user,
      'p_role': role,
    });
  }

  Future<void> leave(String id) async {
    await call('leave_household', {'p_household': id});
  }

  Future<AccountDocument> loadState(String id) async {
    final row = await client
        .from('household_state')
        .select('data,revision')
        .eq('household_id', id)
        .single()
        .timeout(const Duration(seconds: 15));
    return AccountDocument(
      Map<String, dynamic>.from(row['data'] as Map),
      (row['revision'] as num).toInt(),
    );
  }

  Future<int> saveState(
    String id,
    Map<String, dynamic> data,
    int revision,
  ) async => (await call('save_household_state', {
    'p_household': id,
    'p_data': data,
    'p_revision': revision,
  }) as num).toInt();
}

class HouseholdWeeklyPlanRepository implements WeeklyPlanRepository {
  HouseholdWeeklyPlanRepository(this.client, this.householdId);
  final SupabaseClient client;
  final String householdId;
  final revisions = <String, int>{};
  @override
  Future<WeeklyPlan> load(DateTime week, List<Recipe> recipes) async {
    final key = dateKey(week);
    final row = await client
        .from('household_week_plans')
        .select('meals,checked,revision')
        .eq('household_id', householdId)
        .eq('week_start', key)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    revisions[key] = (row?['revision'] as num?)?.toInt() ?? 0;
    return row == null ? WeeklyPlan() : WeeklyPlan.fromJson(row, recipes);
  }

  @override
  Future<void> save(DateTime week, WeeklyPlan plan) async {
    final key = dateKey(week);
    if (!revisions.containsKey(key)) {
      throw StateError('Wochenplan zuerst laden.');
    }
    final value = plan.toJson();
    final revision = await client
        .rpc(
          'save_household_week',
          params: {
            'p_household': householdId,
            'p_week': key,
            'p_meals': value['meals'],
            'p_checked': value['checked'],
            'p_revision': revisions[key],
          },
        )
        .timeout(const Duration(seconds: 20));
    revisions[key] = (revision as num).toInt();
  }
}
