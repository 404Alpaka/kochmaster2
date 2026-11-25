import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/meal_planning/domain/cooking_progress.dart';
import 'package:kochmaster/features/meal_planning/domain/cooking_timer.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';

void main() {
  const recipe = Recipe(
    id: 'test-recipe',
    name: 'Testrezept',
    minutes: 20,
    servings: 2,
    ingredients: [],
    steps: ['Kochen', 'Servieren'],
  );

  test('timer calculates remaining time from a deadline', () {
    final timer = CookingTimer(300);
    timer.toggle();
    expect(timer.remaining, inInclusiveRange(299, 300));
  });

  test('pause and resume preserve the remaining time', () {
    final timer = CookingTimer(120);
    timer.toggle();
    expect(timer.running, isTrue);
    timer.toggle();
    expect(timer.running, isFalse);
    timer.toggle();
    expect(timer.running, isTrue);
  });

  test('reset restores the configured duration', () {
    final timer = CookingTimer(90);
    timer.toggle();
    timer.addMinute();
    timer.reset();
    expect(timer.remaining, 150);
    expect(timer.started, isFalse);
  });

  test('independent timers keep separate deadlines', () {
    final pasta = CookingTimer(600);
    final sauce = CookingTimer(180);
    pasta.toggle();
    sauce.toggle();
    expect(pasta.running, isTrue);
    expect(sauce.running, isTrue);
    pasta.toggle();
    expect(pasta.running, isFalse);
    expect(sauce.running, isTrue);
  });

  test('cooking progress preserves recipe, portions, step, and timer deadline', () {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    final timer = CookingTimer(120)
      ..started = true
      ..deadline = deadline;
    final progress = CookingProgress(
      recipe: recipe,
      portions: 4,
      step: 1,
      key: '2026-11-23:test-recipe',
      date: DateTime(2026, 11, 23),
      day: 0,
      timers: {1: timer},
    );

    final restored = CookingProgress.fromJson(
      jsonDecode(jsonEncode(progress.toJson())) as Map<String, dynamic>,
    );

    expect(restored.recipe.id, recipe.id);
    expect(restored.portions, 4);
    expect(restored.step, 1);
    expect(restored.key, progress.key);
    expect(restored.timers[1]!.deadline, deadline);
    expect(restored.timers[1]!.running, isTrue);
  });

  test('expired timer remains detectable after restoring progress', () {
    final timer = CookingTimer(60)
      ..started = true
      ..deadline = DateTime.now().subtract(const Duration(seconds: 1));
    final progress = CookingProgress(
      recipe: recipe,
      portions: 2,
      step: 0,
      key: '2026-11-23:test-recipe',
      date: DateTime(2026, 11, 23),
      day: null,
      timers: {0: timer},
    );

    final restored = CookingProgress.fromJson(
      jsonDecode(jsonEncode(progress.toJson())) as Map<String, dynamic>,
    );

    expect(restored.timers[0]!.remaining, 0);
    expect(restored.timers[0]!.announced, isFalse);
  });
}
