import 'package:supabase/supabase.dart';

import '../../recipes/domain/recipe.dart';
import '../domain/meal_plan.dart';

DateTime mondayOf(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class WeeklyPlan {
  WeeklyPlan({Map<int, PlannedMeal>? meals, Set<(String, String)>? checked})
    : meals = meals ?? {},
      checked = checked ?? {};
  final Map<int, PlannedMeal> meals;
  final Set<(String, String)> checked;
  Map<String, dynamic> toJson() => {
    'meals': [
      for (final entry in meals.entries)
        {
          'day': entry.key,
          'recipe_id': entry.value.recipe.id,
          'recipe': recipeSnapshot(entry.value.recipe),
          'servings': entry.value.servings,
          'prepared_meal_id': entry.value.preparedMealId,
          'prepared_consumed': entry.value.preparedConsumed,
        },
    ],
    'checked': [
      for (final item in checked) {'ingredient_id': item.$1, 'unit': item.$2},
    ],
  };
  factory WeeklyPlan.fromJson(Map<String, dynamic> data, List<Recipe> recipes) {
    final byId = {for (final recipe in recipes) recipe.id: recipe};
    final plan = WeeklyPlan();
    for (final value in data['meals'] as List) {
      final row = value as Map<String, dynamic>;
      final day = row['day'] as int;
      final recipe = row['recipe'] is Map<String, dynamic>
          ? recipeFromSnapshot(row['recipe'] as Map<String, dynamic>)
          : byId[row['recipe_id']];
      if (recipe == null) {
        throw StateError('Ein geplantes Rezept ist nicht mehr verfügbar.');
      }
      if (day < 0 || day > 6 || plan.meals.containsKey(day)) {
        throw const FormatException('Ungültiger Wochentag');
      }
      plan.meals[day] = PlannedMeal(
        recipe,
        row['servings'] as int,
        preparedMealId: row['prepared_meal_id'] as String?,
        preparedConsumed: row['prepared_consumed'] == true,
      );
    }
    for (final value in data['checked'] as List) {
      final row = value as Map<String, dynamic>;
      plan.checked.add((row['ingredient_id'] as String, row['unit'] as String));
    }
    return plan;
  }
}

abstract interface class WeeklyPlanRepository {
  Future<WeeklyPlan> load(DateTime week, List<Recipe> recipes);
  Future<void> save(DateTime week, WeeklyPlan plan);
}

class SupabaseWeeklyPlanRepository implements WeeklyPlanRepository {
  SupabaseWeeklyPlanRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  final _revisions = <String, int>{};
  @override
  Future<WeeklyPlan> load(DateTime week, List<Recipe> recipes) async {
    final row = await client
        .from('user_week_plans')
        .select('meals,checked,revision')
        .eq('user_id', userId)
        .eq('week_start', dateKey(week))
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    final plan = row == null ? WeeklyPlan() : WeeklyPlan.fromJson(row, recipes);
    _revisions[dateKey(week)] = (row?['revision'] as num?)?.toInt() ?? 0;
    return plan;
  }

  @override
  Future<void> save(DateTime week, WeeklyPlan plan) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Bitte erneut anmelden.');
    }
    final key = dateKey(week);
    if (!_revisions.containsKey(key)) {
      throw StateError('Wochenplan zuerst laden.');
    }
    final data = plan.toJson();
    final revision = await client
        .rpc(
          'save_user_week_plan',
          params: {
            'p_user': userId,
            'p_week': key,
            'p_meals': data['meals'],
            'p_checked': data['checked'],
            'p_revision': _revisions[key],
          },
        )
        .timeout(const Duration(seconds: 15));
    _revisions[key] = (revision as num).toInt();
  }
}
