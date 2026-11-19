import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/features/meal_planning/domain/planning_diner.dart';
import 'package:kochmaster/features/meal_planning/presentation/household_diners_page.dart';

void main() {
  testWidgets('member rules require explicit declaration, save and reopen', (
    tester,
  ) async {
    List<PlanningDiner>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<List<PlanningDiner>>(
                  MaterialPageRoute(
                    builder: (_) => HouseholdDinersPage(
                      initial:
                          saved ?? const [PlanningDiner(id: 'a', name: 'Anna')],
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Feste Regeln noch unbekannt'), findsOneWidget);
    await tester.tap(find.text('Feste Regeln bearbeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Milch'));
    await tester.pumpAndSettle();
    final declaration = find.widgetWithText(
      CheckboxListTile,
      'Angaben geprüft – auch keine Allergien ist eine ausdrückliche Angabe.',
    );
    await tester.ensureVisible(declaration);
    await tester.tap(declaration);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemeinsame Regeln speichern'));
    await tester.pumpAndSettle();
    expect(saved!.single.confirmed, isTrue);
    expect(saved!.single.exclusions, {'Milch'});
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Milch'), findsOneWidget);
    expect(find.text('Feste Regeln noch unbekannt'), findsNothing);
  });
  testWidgets('viewers can inspect declarations but cannot edit or save', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HouseholdDinersPage(
          initial: [PlanningDiner(id: 'a', name: 'Anna', confirmed: true)],
          readOnly: true,
        ),
      ),
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Feste Regeln bearbeiten'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    expect(find.text('Gemeinsame Regeln speichern'), findsNothing);
  });
}
