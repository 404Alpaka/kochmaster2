import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kochmaster/core/local_store.dart';
import 'package:kochmaster/features/auth/data/session_storage.dart';
import 'package:kochmaster/features/meal_planning/data/offline_cache.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/recipes/data/cached_recipe_repository.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';

class _Failures {
  bool read = false;
  bool write = false;
}

class _Preferences extends SharedPreferencesAsync {
  _Preferences(this.failures);
  final _Failures failures;
  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) {
    if (failures.read) throw StateError('unreadable');
    return super.getAll(allowList: allowList);
  }

  @override
  Future<void> setString(String key, String value) {
    if (failures.write) throw StateError('full');
    return super.setString(key, value);
  }
}

class _Recipes implements RecipeRepository {
  List<Recipe> recipes = DemoRecipeRepository().getAll();
  Object? failure;
  Completer<void>? gate;
  @override
  Future<List<Recipe>> getAll() async {
    await gate?.future;
    if (failure != null) throw failure!;
    return recipes;
  }
}

Recipe _rice(String id, double amount, String unit) => Recipe(
  id: id,
  name: id,
  minutes: 10,
  servings: 2,
  ingredients: [IngredientAmount('rice', 'Reis', amount, unit)],
  steps: const ['Kochen.'],
);

void main() {
  test(
    'Native preferences, theme and guest data survive a new store instance',
    () async {
      writeSession('mise-theme-mode', 'dark');
      writeSession('mise-preferences-guest', '{"pantry":[{"name":"Bananen"}]}');
      await LocalStore.instance.flush();
      final restarted = LocalStore(
        preferences: LocalStore.instance.preferences,
      );
      await restarted.initialize();
      LocalStore.instance = restarted;
      expect(readSession('mise-theme-mode'), 'dark');
      expect(readSession('mise-preferences-guest'), contains('Bananen'));
      await removeSessionValues(['mise-preferences-guest']);
      final afterRemoval = LocalStore(preferences: restarted.preferences);
      await afterRemoval.initialize();
      expect(afterRemoval.read('preference:mise-preferences-guest'), isNull);
      expect(afterRemoval.read('preference:mise-theme-mode'), 'dark');
    },
  );

  test(
    'A failed confirmed write does not expose an unsaved cache value',
    () async {
      final failures = _Failures();
      final store = LocalStore(preferences: _Preferences(failures));
      await store.initialize();
      await store.write('week', 'old', optimistic: false);
      failures.write = true;
      await expectLater(
        store.write('week', 'new', optimistic: false),
        throwsStateError,
      );
      expect(store.read('week'), 'old');
      expect(store.issue.value, isNotNull);
      failures.write = false;
      final restarted = LocalStore(preferences: store.preferences);
      await restarted.initialize();
      expect(restarted.read('week'), 'old');
    },
  );

  test(
    'Failed initial reads never overwrite previously unseen device data',
    () async {
      final failures = _Failures();
      final preferences = _Preferences(failures);
      final first = LocalStore(preferences: preferences);
      await first.initialize();
      await first.write('private', 'keep');
      failures.read = true;
      final failed = LocalStore(preferences: preferences);
      await failed.initialize();
      await expectLater(failed.write('private', 'replace'), throwsStateError);
      failures.read = false;
      final restarted = LocalStore(preferences: preferences);
      await restarted.initialize();
      expect(restarted.read('private'), 'keep');
    },
  );

  test('Catalog is available after restart and a failed optional refresh keeps it usable', () async {
    final source = _Recipes();
    final initial = CachedRecipeRepository(source, project: 'one');
    expect(await initial.getAll(), hasLength(2));
    final store = LocalStore(preferences: LocalStore.instance.preferences);
    await store.initialize();
    final offlineSource = _Recipes()..failure = http.ClientException('offline');
    final cached = CachedRecipeRepository(
      offlineSource,
      project: 'one',
      store: store,
    );
    expect(await cached.getAll(), hasLength(2));
    await cached.refresh();
    expect(cached.snapshot.value!.offline, isTrue);
    expect(
      CachedRecipeRepository(
        offlineSource,
        project: 'two',
        store: store,
      ).readCache(),
      isNull,
    );
    offlineSource.failure = null;
    offlineSource.recipes = [];
    await cached.refresh();
    expect(cached.snapshot.value!.recipes, isEmpty);
    expect(cached.readCache()!.recipes, isEmpty);
  });

  test('Offline check reconciliation keeps remote meals and checks and rejects changed requirements', () async {
    final cache = OfflineCache(project: 'p', user: 'a');
    final week = DateTime(2026, 11, 23);
    final original = WeeklyPlan(
      meals: {0: PlannedMeal(_rice('old', 0.5, 'kg'), 2)},
      checked: {('rice', 'g')},
    );
    const extra = [IngredientAmount('banana', 'Bananen', 2, 'Stk.')];
    await cache.saveWeek(week, 'private', original, extras: extra);
    await cache.saveWeek(
      week,
      'private',
      WeeklyPlan(meals: original.meals, checked: {('banana', 'Stück')}),
      pending: true,
      extras: extra,
    );
    final restarted = LocalStore(preferences: LocalStore.instance.preferences);
    await restarted.initialize();
    final saved = OfflineCache(
      project: 'p',
      user: 'a',
      store: restarted,
    ).readWeek(week, 'private')!;
    expect(saved.pending, isTrue);
    const other = Recipe(
      id: 'broccoli',
      name: 'Brokkoli',
      minutes: 10,
      servings: 2,
      ingredients: [IngredientAmount('broccoli', 'Brokkoli', 300, 'g')],
      steps: ['Garen.'],
    );
    final remote = WeeklyPlan(
      meals: {
        0: PlannedMeal(_rice('new', 500, 'g'), 2),
        1: PlannedMeal(other, 2),
      },
      checked: {('rice', 'g'), ('broccoli', 'g')},
    );
    final (merged, ignored) = saved.reconcile(remote, extra);
    expect(merged.meals[0]!.recipe.id, 'new');
    expect(merged.meals[1]!.recipe.id, other.id);
    expect(merged.checked, {('banana', 'Stück'), ('broccoli', 'g')});
    expect(ignored, 0);
    final (changed, skipped) = saved.reconcile(remote, const [
      IngredientAmount('banana', 'Bananen', 3, 'Stück'),
    ]);
    expect(changed.checked, {('broccoli', 'g')});
    expect(skipped, 1);
  });

  test(
    'Caches and local cleanup stay isolated by project, account and household',
    () async {
      final first = OfflineCache(project: 'one', user: 'a');
      final other = OfflineCache(project: 'one', user: 'b');
      final week = DateTime(2026, 11, 23);
      final plan = WeeklyPlan(
        meals: {0: PlannedMeal(_rice('rice', 100, 'g'), 2)},
      );
      await first.saveWeek(week, 'private', plan);
      await first.saveWeek(week, 'household', plan);
      await other.saveWeek(week, 'private', plan);
      expect(
        OfflineCache(project: 'two', user: 'a').readWeek(week, 'private'),
        isNull,
      );
      expect(first.readWeek(week, 'different-household'), isNull);
      await first.clear();
      expect(first.readWeeks('private'), isEmpty);
      expect(first.readWeek(week, 'household'), isNull);
      expect(other.readWeek(week, 'private'), isNotNull);
    },
  );
}
