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
    return Container(
      key: const ValueKey('bottom-navigation-surface'),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .4)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  for (final (tab, label, icon, _) in destinations)
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
                            borderRadius: BorderRadius.circular(18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 2,
                              ),
                              decoration: BoxDecoration(
                                color: selectedTab == tab
                                    ? colors.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icon,
                                    size: 25,
                                    color: selectedTab == tab
                                        ? colors.primary
                                        : dark
                                        ? colors.onSurface
                                        : const Color(0xFF7A8079),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selectedTab == tab
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selectedTab == tab
                                          ? colors.primary
                                          : dark
                                          ? colors.onSurface
                                          : const Color(0xFF7A8079),
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
