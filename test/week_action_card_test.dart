import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

import 'planning_page_test.dart' show MemoryWeekStore;

class MissingRevisionStore extends MemoryWeekStore {
  @override
  Future<WeeklyPlan> load(DateTime week, List<Recipe> recipes) async {
    throw const PostgrestException(message: 'column user_week_plans.revision does not exist', code: '42703');
  }
}

void main() {
  final recipes = DemoRecipeRepository().getAll();
  final today = DateTime.now().weekday - 1;
  final week = mondayOf(DateTime.now());
  Future<void> open(WidgetTester tester, MemoryWeekStore store) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PlanningPage(recipes: recipes, isDemo: false, store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
  }

  testWidgets('Kommende Wochen getrennt bearbeiten und wieder öffnen', (tester) async {
    final store = MemoryWeekStore();
    final next = DateTime(week.year, week.month, week.day + 7);
    await store.save(week, WeeklyPlan(meals: {today: PlannedMeal(recipes.first, 2)}));
    await store.save(next, WeeklyPlan(meals: {0: PlannedMeal(recipes.last, 4)}));
    await open(tester, store);
    expect(find.text('Diese Woche'), findsOneWidget);
    await tester.tap(find.byTooltip('Nächste Woche'));
    await tester.pumpAndSettle();
    expect(find.text('Nächste Woche'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('increase-0')), 150,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('increase-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('increase-0')));
    await tester.pumpAndSettle();
    expect(WeeklyPlan.fromJson(store.rows[dateKey(next)]!, recipes).meals[0]!.servings, 5);
    expect(WeeklyPlan.fromJson(store.rows[dateKey(week)]!, recipes).meals[today]!.servings, 2);
    await tester.scrollUntilVisible(find.text('Zur aktuellen Woche'), -200,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Zur aktuellen Woche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zur aktuellen Woche'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Vorherige Woche'), -200,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Diese Woche'), findsOneWidget);
    await tester.tap(find.byTooltip('Nächste Woche'));
    await tester.pumpAndSettle();
    expect(find.text(recipes.last.name), findsWidgets);
    await tester.tap(find.text('Woche auswählen'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Datumsauswahl öffnet Zielwoche und schützt den Entwurf', (tester) async {
    final store = MemoryWeekStore();
    final target = DateTime(2027, 1, 11);
    await store.save(target, WeeklyPlan(meals: {0: PlannedMeal(recipes.last, 3)}));
    await open(tester, store);
    await tester.tap(find.text('Woche auswählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '01/11/2027');
    await tester.tap(find.text('Woche öffnen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('11.1.2027 – 17.1.2027'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Wochenplan bearbeiten'), 150,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wochenplan bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Woche auswählen'), findsOneWidget);
    await tester.tap(find.byTooltip('Nächste Woche'));
    await tester.pumpAndSettle();
    expect(find.text('Woche wechseln?'), findsOneWidget);
    await tester.tap(find.text('Hier bleiben'));
    await tester.pumpAndSettle();
    expect(find.text('Wochenplan bestätigen'), findsOneWidget);
    await tester.tap(find.byTooltip('Nächste Woche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Woche wechseln'));
    await tester.pumpAndSettle();
    expect(find.text('Wochenplan erstellen'), findsOneWidget);
    expect(find.textContaining('18.1.2027 – 24.1.2027'), findsWidgets);
    expect(store.rows[dateKey(target)], isNotNull);
    expect(store.rows[dateKey(DateTime(2027, 1, 18))], isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Startseite startet das heutige Gericht mit geplanten Portionen', (tester) async {
    final store = MemoryWeekStore();
    await store.save(week, WeeklyPlan(meals: {today: PlannedMeal(recipes.first, 4)}));
    await open(tester, store);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Kochen starten'), findsOneWidget);
    await tester.tap(find.text('Kochen starten'));
    await tester.pumpAndSettle();
    expect(find.text('Zeit zu kochen.'), findsOneWidget);
    expect(find.text('4 Portionen'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Leerer Plan startet die Planung direkt im grünen Feld', (
    tester,
  ) async {
    await open(tester, MemoryWeekStore());
    expect(find.text('Wochenplan erstellen'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('week-primary-action')));
    await tester.pumpAndSettle();
    expect(find.text('1 von 4'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ladefehler blockiert nicht das Vorbereiten eines Vorschlags', (tester) async {
    final store = MissingRevisionStore();
    await open(tester, store);
    expect(find.textContaining('Du kannst einen Vorschlag vorbereiten'), findsOneWidget);
    await tester.tap(find.text('Wochenplan erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('1 von 4'), findsOneWidget);
    await tester.tap(find.text('Weiter: Ernährungsweise'));
    await tester.pumpAndSettle();
    expect(find.text('2 von 4'), findsOneWidget);
    expect(store.saveCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Geplante Portionen kochen und danach als erledigt anzeigen', (
    tester,
  ) async {
    final store = MemoryWeekStore();
    await store.save(
      week,
      WeeklyPlan(meals: {today: PlannedMeal(recipes.first, 2)}),
    );
    await open(tester, store);
    expect(find.text('Heute auf dem Teller'), findsOneWidget);
    expect(find.text('Jetzt kochen'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('week-primary-action')));
    await tester.pumpAndSettle();
    expect(find.text('Zeit zu kochen.'), findsOneWidget);
    expect(find.text('2 Portionen'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Kochen starten'));
    await tester.pumpAndSettle();
    for (var i = 1; i < recipes.first.steps.length; i++) {
      await tester.tap(
        find.widgetWithText(FilledButton, 'Weiter: Schritt ${i + 1}'),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Gekocht markieren ✓'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Vorrat & 0 Portionen speichern'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Heute erledigt ✓'), findsOneWidget);
    expect(find.text('Jetzt kochen'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('week-primary-action')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mehr Portionen'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Freier Tag und andere Kalenderwoche tragen das richtige Datum', (
    tester,
  ) async {
    final store = MemoryWeekStore();
    await store.save(
      week,
      WeeklyPlan(meals: {(today + 1) % 7: PlannedMeal(recipes.first, 2)}),
    );
    await store.save(
      week.add(const Duration(days: 7)),
      WeeklyPlan(meals: {today: PlannedMeal(recipes.last, 3)}),
    );
    await open(tester, store);
    expect(find.textContaining('Heute ist nichts geplant'), findsOneWidget);
    expect(find.text('Gericht hinzufügen'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('Nächste Woche'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Nächste Woche'));
    await tester.pumpAndSettle();
    expect(find.text('Heute auf dem Teller'), findsNothing);
    await tester.scrollUntilVisible(find.text(['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][today]), 150,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][today]));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('week-primary-action')),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('auf dem Teller'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('week-primary-action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('week-primary-action')));
    await tester.pumpAndSettle();
    expect(find.text('Zeit zu kochen.'), findsOneWidget);
    expect(find.text('3 Portionen'), findsOneWidget);
    final expected = week.add(Duration(days: 7 + today));
    expect(
      find.textContaining('${expected.day}.${expected.month}.${expected.year}'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
