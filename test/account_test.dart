import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/auth/presentation/account_page.dart';
import 'package:kochmaster/features/meal_planning/data/weekly_plan_repository.dart';
import 'package:kochmaster/features/meal_planning/domain/meal_plan.dart';
import 'package:kochmaster/features/recipes/data/demo_recipe_repository.dart';

void main() {
  test('Kalenderwochen und gespeicherte Einkaufspositionen überleben Serialisierung', () {
    expect(dateKey(mondayOf(DateTime(2027, 1, 3))), '2026-12-28');
    final recipes = DemoRecipeRepository().getAll();
    final plan = WeeklyPlan(
      meals: {2: PlannedMeal(recipes.first, 4)},
      checked: {('tomato', 'g')},
    );
    final restored = WeeklyPlan.fromJson(plan.toJson(), recipes);
    expect(restored.meals[2]!.recipe.id, recipes.first.id);
    expect(restored.meals[2]!.servings, 4);
    expect(restored.checked, {('tomato', 'g')});
    expect(
      WeeklyPlan.fromJson(plan.toJson(), []).meals[2]!.recipe.id,
      recipes.first.id,
    );
  });
  testWidgets('Login und Registrierung validieren Eingaben ohne Netzwerk', (
    tester,
  ) async {
    final client = (await tester.runAsync(
      () async =>
          SupabaseClient('https://example.supabase.co', 'public-test-key'),
    ))!;
    addTearDown(() => tester.runAsync(client.dispose));
    await tester.pumpWidget(MaterialApp(home: AccountPage(client: client)));
    await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte gib deine E-Mail-Adresse ein.'), findsOneWidget);
    expect(find.text('Bitte gib dein Passwort ein.'), findsOneWidget);
    await tester.tap(find.text('Neues Konto erstellen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Fabian');
    await tester.enterText(find.byType(TextFormField).at(1), 'Mustermann');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(3), 'long-enough');
    await tester.enterText(find.byType(TextFormField).at(4), 'different');
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Registrieren'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrieren'));
    await tester.pumpAndSettle();
    expect(find.text('Die Passwörter stimmen nicht überein.'), findsOneWidget);
  });
}
