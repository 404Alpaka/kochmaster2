import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/app_bottom_navigation.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('Navigation covers bottom inset and switches tabs at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 5;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              padding: const EdgeInsets.only(bottom: 34),
              textScaler: TextScaler.linear(1.3),
            ),
            child: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: AppBottomNavigation(
                  selectedTab: selected,
                  onSelect: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      );
      final surface = find.byKey(const ValueKey('bottom-navigation-surface'));
      expect(tester.getRect(surface).bottom, 900);
      expect(tester.getRect(find.text('Start')).bottom, lessThanOrEqualTo(866));
      final startY = tester.getCenter(find.text('Start')).dy;
      for (final (tab, label, _, _) in AppBottomNavigation.destinations) {
        expect(tester.getCenter(find.text(label)).dy, startY);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(selected, tab);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
