import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/meal_planning/presentation/food_preferences_page.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

import 'planning_page_test.dart' show MemoryWeekStore;
import 'scroll_helpers.dart';

void main() {
  testWidgets(
    'Home preferences are retained on reopening and leave existing week intact',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recipes = DemoRecipeRepository().getAll();
      final store = MemoryWeekStore();
      await store.save(
        mondayOf(DateTime.now()),
        WeeklyPlan(meals: {0: PlannedMeal(recipes.first, 2)}),
      );
      final original = store.rows.toString();
      final user = User.fromJson({
        'id': 'food-pref-test',
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-11-19T12:00:00Z',
      });
      Widget app() => MaterialApp(
        theme: AppTheme.light,
        home: PlanningPage(
          recipes: recipes,
          isDemo: false,
          store: store,
          user: user,
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('food-preferences-card'));
      await reveal(tester, card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Vegetarisch'));
      await tester.pumpAndSettle();
      final more = find.byTooltip('Mehr Personen');
      await reveal(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('food-preferences-budget'));
      await reveal(tester, field);
      await tester.enterText(field, '85,50');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Präferenzen übernehmen'));
      await tester.pumpAndSettle();
      expect(store.rows.toString(), original);
      expect(card, findsNothing);
      final profile = find.byTooltip('Zum Profil');
      await reveal(tester, profile, delta: -200);
      await tester.tap(profile);
      await tester.pumpAndSettle();
      final preferences = find.text('Essenspräferenzen');
      await reveal(tester, preferences);
      await tester.tap(preferences);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Vegetarisch'))
            .selected,
        isTrue,
      );
      final restored = find.byKey(const ValueKey('food-preferences-budget'));
      await reveal(tester, restored);
      expect(tester.widget<TextFormField>(restored).controller!.text, '85,50');
      expect(store.saveCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Completed preferences hide home card and skip repeat budget step',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PlanningPage(
            isDemo: true,
            recipes: DemoRecipeRepository().getAll(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('food-preferences-card'));
      await reveal(tester, card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      final budget = find.byKey(const ValueKey('food-preferences-budget'));
      await reveal(tester, budget);
      await tester.enterText(budget, '40');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Präferenzen übernehmen'));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('week-primary-action')));
      await tester.pumpAndSettle();
      expect(find.byType(FoodPreferencesPage), findsNothing);
      expect(find.text('Deine Woche. Dein Mix.'), findsOneWidget);
      expect(find.text('Was darf dein Plan kosten?'), findsNothing);
      expect(find.textContaining('Budgetkonflikt'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Invalid budget prevents accepting preferences', (tester) async {
    FoodPreferences? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Öffnen'),
              onPressed: () async {
                result = await Navigator.push<FoodPreferences>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FoodPreferencesPage(
                      initial: FoodPreferences(
                        diet: 'Ohne Einschränkung',
                        exclusions: {},
                        servings: 2,
                        days: 7,
                        minutes: 30,
                        budget: 75,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('food-preferences-budget'));
    await reveal(tester, field);
    await tester.enterText(field, '-1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Präferenzen übernehmen'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.textContaining('Bitte ein Budget'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
