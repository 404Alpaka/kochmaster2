import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/connection_failure.dart';
import '../../../core/local_store.dart';
import '../domain/recipe.dart';

class CatalogSnapshot {
  const CatalogSnapshot(this.recipes, this.savedAt, {this.offline = false});
  final List<Recipe> recipes;
  final DateTime savedAt;
  final bool offline;
}

class CachedRecipeRepository implements RecipeRepository {
  CachedRecipeRepository(
    this.source, {
    required String project,
    LocalStore? store,
  }) : key = 'catalog:${Uri.encodeComponent(project)}',
       store = store ?? LocalStore.instance;
  final RecipeRepository source;
  final String key;
  final LocalStore store;
  final snapshot = ValueNotifier<CatalogSnapshot?>(null);
  Future<List<Recipe>>? _refreshing;

  CatalogSnapshot? readCache() {
    try {
      final raw = store.read(key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map;
      if (data['version'] != 1) return null;
      return CatalogSnapshot([
        for (final value in data['recipes'] as List)
          recipeFromSnapshot(Map<String, dynamic>.from(value as Map)),
      ], DateTime.parse(data['saved_at'] as String));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Recipe>> getAll() async {
    final cached = snapshot.value ?? readCache();
    if (cached != null) {
      snapshot.value = cached;
      unawaited(refresh().catchError((Object _) => cached.recipes));
      return cached.recipes;
    }
    return refresh();
  }

  Future<List<Recipe>> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<List<Recipe>> _refresh() async {
    try {
      final recipes = await Future.sync(source.getAll);
      final now = DateTime.now().toUtc();
      try {
        await store.write(
          key,
          jsonEncode({
            'version': 1,
            'saved_at': now.toIso8601String(),
            'recipes': recipes.map(recipeSnapshot).toList(),
          }),
        );
      } catch (_) {
        /* Online recipes remain usable when caching fails. */
      }
      snapshot.value = CatalogSnapshot(recipes, now);
      return recipes;
    } catch (error) {
      final cached = snapshot.value ?? readCache();
      if (cached != null && isConnectionFailure(error)) {
        snapshot.value = CatalogSnapshot(
          cached.recipes,
          cached.savedAt,
          offline: true,
        );
        return cached.recipes;
      }
      rethrow;
    }
  }
}
