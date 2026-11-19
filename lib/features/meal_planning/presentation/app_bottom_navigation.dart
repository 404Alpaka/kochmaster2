import 'package:material_ui/material_ui.dart';

/// Keeps the navigation surface continuous behind the phone's home indicator.
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
    return Material(
      key: const ValueKey('bottom-navigation-surface'),
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.onSurface.withValues(alpha: .08),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Row(
                children: [
                  for (final (tab, label, icon, activeIcon) in destinations)
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
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    width: 52,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: selectedTab == tab
                                          ? colors.primaryContainer
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      selectedTab == tab ? activeIcon : icon,
                                      size: 23,
                                      color: selectedTab == tab
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
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
                                          : colors.onSurfaceVariant,
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
    );
  }
}
