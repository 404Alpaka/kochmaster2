import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';
import 'package:kochmaster/features/recipes/domain/recipe.dart';

import 'scroll_helpers.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'Gleich große Rezeptkarten bei $width und Textfaktor $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final recipes = [
            for (var i = 0; i < 5; i++)
              Recipe(
                id: 'grid-$i',
                name: i.isEven ? 'Reis' : 'Sehr langer Rezeptname mit vielen Zutaten und weiteren Informationen für ein großes Abendessen',
                minutes: i.isEven ? 5 : 9999,
                servings: i.isEven ? 1 : 999,
                categories: const {'meat'},
                ingredients: const [IngredientAmount('rice', 'Reis', 100, 'g')],
                steps: const ['Kochen'],
              ),
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: PlanningPage(isDemo: true, recipes: recipes),
            ),
          );
          await tester.tap(find.text('Rezepte'));
          await tester.pumpAndSettle();
          await reveal(tester, find.text('5 von 5 Rezepten'));
          final cards = find.byWidgetPredicate(
            (widget) =>
                widget is Card &&
                widget.key is ValueKey<String> &&
                (widget.key as ValueKey<String>).value.startsWith(
                  'compact-recipe-card-',
                ),
          );
          expect(cards.evaluate().length, greaterThanOrEqualTo(2));
          final size = tester.getSize(cards.first);
          for (var i = 1; i < cards.evaluate().length; i++) {
            expect(tester.getSize(cards.at(i)), size);
          }
          expect(find.text('Aktionen'), findsNothing);
          expect(find.text('Mehr'), findsNothing);
          expect(size.width, lessThan(width / 2));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
