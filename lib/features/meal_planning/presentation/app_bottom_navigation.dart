import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedTab,
    required this.onSelect,
  });

  final int selectedTab;
  final ValueChanged<int> onSelect;

  static const destinations = [
    (5, 'Start', Icons.home_outlined, Icons.home_rounded),
    (0, 'Rezepte', Icons.menu_book_outlined, Icons.menu_book_rounded),
    (1, 'Plan', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
    (2, 'Vorrat', Icons.kitchen_outlined, Icons.kitchen_rounded),
    (3, 'Korb', Icons.shopping_cart_outlined, Icons.shopping_cart_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: colors.onSurface.withValues(alpha: .10),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  key: const ValueKey('bottom-navigation-surface'),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: dark ? .88 : .82),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: dark
                          ? colors.outlineVariant
                          : Colors.white.withValues(alpha: .9),
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Row(
                      children: [
                        for (final (tab, label, icon, activeIcon)
                            in destinations)
                          Expanded(
                            child: Semantics(
                              selected: selectedTab == tab,
                              button: true,
                              label: label,
                              excludeSemantics: true,
                              onTap: () => onSelect(tab),
                              child: Tooltip(
                                message: label,
                                child: InkWell(
                                  onTap: () => onSelect(tab),
                                  borderRadius: BorderRadius.circular(32),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedTab == tab
                                          ? colors.primaryContainer.withValues(
                                              alpha: .85,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          selectedTab == tab
                                              ? activeIcon
                                              : icon,
                                          size: 24,
                                          color: selectedTab == tab
                                              ? colors.primary
                                              : colors.onSurface,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          label,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.2,
                                            fontWeight: selectedTab == tab
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: selectedTab == tab
                                                ? colors.primary
                                                : colors.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
