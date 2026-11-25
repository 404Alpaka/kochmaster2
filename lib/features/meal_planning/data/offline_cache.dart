import 'dart:convert';

import '../../../core/local_store.dart';
import '../../recipes/domain/recipe.dart';
import '../../shopping/domain/build_shopping_list.dart';
import 'weekly_plan_repository.dart';

class CachedWeek {
  CachedWeek(this.data);
  final Map<String, dynamic> data;
  bool get pending => data['pending'] == true;
  WeeklyPlan get plan => WeeklyPlan.fromJson(
    Map<String, dynamic>.from(data['plan'] as Map),
    const [],
  );
  DateTime? get savedAt => DateTime.tryParse(data['saved_at'] as String? ?? '');

  (WeeklyPlan, int) reconcile(
    WeeklyPlan remote,
    List<IngredientAmount> currentExtras,
  ) {
    final base = WeeklyPlan.fromJson(
      Map<String, dynamic>.from(data['base'] as Map),
      const [],
    );
    final local = plan;
    final extras = (data['extras'] as List? ?? [])
        .map(
          (value) => IngredientAmount(
            value['ingredient_id'] as String,
            value['name'] as String,
            (value['quantity'] as num).toDouble(),
            value['unit'] as String,
          ),
        )
        .toList();
    final oldChecks = normalizeCheckedItems(
      base.meals.values,
      base.checked,
      additionalItems: extras,
    );
    final localChecks = normalizeCheckedItems(
      local.meals.values,
      local.checked,
      additionalItems: extras,
    );
    final touched = oldChecks
        .difference(localChecks)
        .union(localChecks.difference(oldChecks));
    final before = buildShoppingList(
      base.meals.values,
      additionalItems: extras,
    );
    final after = buildShoppingList(
      remote.meals.values,
      additionalItems: currentExtras,
    );
    final safe = retainCheckedQuantities(before, after, touched);
    final merged = normalizeCheckedItems(
      remote.meals.values,
      remote.checked,
      additionalItems: currentExtras,
    );
    for (final key in safe) {
      if (localChecks.contains(key)) {
        merged.add(key);
      } else {
        merged.remove(key);
      }
    }
    return (
      WeeklyPlan(meals: remote.meals, checked: merged),
      touched.length - safe.length,
    );
  }
}

class OfflineCache {
  OfflineCache({
    required String project,
    required String user,
    LocalStore? store,
  }) : prefix =
           'offline:${Uri.encodeComponent(project)}:${Uri.encodeComponent(user)}:',
       store = store ?? LocalStore.instance;
  final String prefix;
  final LocalStore store;
  String _weekKey(DateTime week, String scope) =>
      '${prefix}week:${Uri.encodeComponent(scope)}:${dateKey(week)}';

  Map<String, dynamic>? _read(String key) {
    try {
      final raw = store.read(key);
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? readAccount() => _read('${prefix}account');
  Future<void> saveAccount(Map<String, dynamic> data) =>
      store.write('${prefix}account', jsonEncode(data), optimistic: false);

  CachedWeek? readWeek(DateTime week, String scope) {
    try {
      final data = _read(_weekKey(week, scope));
      if (data == null || data['version'] != 1) return null;
      final cached = CachedWeek(data);
      cached
          .plan; // Validate snapshots before exposing them as an offline plan.
      return cached;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWeek(
    DateTime week,
    String scope,
    WeeklyPlan plan, {
    bool pending = false,
    List<IngredientAmount> extras = const [],
  }) {
    final previous = pending ? readWeek(week, scope) : null;
    return store.write(
      _weekKey(week, scope),
      jsonEncode({
        'version': 1,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'pending': pending,
        'plan': plan.toJson(),
        'base':
            previous?.data['base'] ?? previous?.data['plan'] ?? plan.toJson(),
        'extras':
            previous?.data['extras'] ??
            [
              for (final item in extras)
                {
                  'ingredient_id': item.ingredientId,
                  'name': item.name,
                  'quantity': item.quantity,
                  'unit': item.unit,
                },
            ],
      }),
      optimistic: false,
    );
  }

  Future<void> clear() => store.removePrefix(prefix);

  Map<String, WeeklyPlan> readWeeks(String scope) {
    final start = '${prefix}week:${Uri.encodeComponent(scope)}:';
    final result = <String, WeeklyPlan>{};
    for (final key in store.keys.where((key) => key.startsWith(start))) {
      final date = DateTime.tryParse(key.substring(start.length));
      if (date == null) continue;
      final cached = readWeek(date, scope);
      if (cached != null) result[dateKey(date)] = cached.plan;
    }
    return result;
  }
}
