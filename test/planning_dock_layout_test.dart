import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

import 'planning_page_test.dart' show MemoryWeekStore;
import 'scroll_helpers.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Proposal content stays above fixed actions at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recipes = DemoRecipeRepository().getAll();
      final store = MemoryWeekStore();
      await store.save(
        mondayOf(DateTime.now()),
        WeeklyPlan(
          meals: {
            for (var day = 0; day < 7; day++)
              day: PlannedMeal(recipes[day % recipes.length], 2),
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 850),
              padding: const EdgeInsets.only(bottom: 34),
            ),
            child: PlanningPage(recipes: recipes, isDemo: false, store: store),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Wochenplan bearbeiten'));
      await tester.tap(find.text('Wochenplan bearbeiten'));
      await tester.pumpAndSettle();
      expect(find.text('Wochenplan bestätigen'), findsOneWidget);
      final dock = tester.getRect(
        find.byKey(const ValueKey('app-bottom-dock')),
      );
      expect(
        tester.getRect(find.byType(ListView).first).bottom,
        lessThanOrEqualTo(dock.top),
      );
      final free = find.byKey(const ValueKey('proposal-free-6'));
      await reveal(tester, free);
      await tester.ensureVisible(free);
      await tester.pumpAndSettle();
      expect(tester.getRect(free).bottom, lessThanOrEqualTo(dock.top));
      await tester.tap(free);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wochenplan bestätigen'));
      await tester.pumpAndSettle();
      expect(
        WeeklyPlan.fromJson(
          store.rows[dateKey(mondayOf(DateTime.now()))]!,
          recipes,
        ).meals.length,
        6,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
