import 'package:material_ui/material_ui.dart';

import '../data/admin_recipe_repository.dart';

class IngredientSearchSheet extends StatefulWidget {
  const IngredientSearchSheet({
    super.key,
    required this.catalog,
    this.initialQuery = '',
    this.selectedId,
  });
  final List<CatalogIngredient> catalog;
  final String initialQuery;
  final String? selectedId;

  @override
  State<IngredientSearchSheet> createState() => _IngredientSearchSheetState();
}

class _IngredientSearchSheetState extends State<IngredientSearchSheet> {
  late final controller = TextEditingController(text: widget.initialQuery);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim();
    final matches =
        widget.catalog
            .where((item) => normalize(item.name).contains(normalize(query)))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final exact = widget.catalog.any(
      (item) => normalize(item.name) == normalize(query),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Zutat auswählen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Zutatensuche schließen',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            key: const ValueKey('ingredient-search'),
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Zutat suchen, z. B. Tomate',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Zutatensuche leeren',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(controller.clear),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount:
                matches.length +
                (matches.isEmpty ? 1 : 0) +
                (query.isNotEmpty && !exact && query.length <= 120 ? 1 : 0),
            itemBuilder: (context, index) {
              var resultIndex = index;
              if (matches.isEmpty) {
                if (resultIndex == 0) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Keine passende Zutat gefunden.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                resultIndex--;
              }
              if (query.isNotEmpty && !exact && query.length <= 120) {
                if (resultIndex == 0) {
                  return ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text('„$query“ neu anlegen'),
                    subtitle: const Text('Wird mit dem Rezept gespeichert'),
                    onTap: () =>
                        Navigator.pop(context, CatalogIngredient('', query)),
                  );
                }
                resultIndex--;
              }
              final item = matches[resultIndex];
              return ListTile(
                key: ValueKey('ingredient-result-${item.id}'),
                leading: const Icon(Icons.restaurant_outlined),
                title: Text(item.name),
                trailing: item.id == widget.selectedId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        ),
      ],
    );
  }
}
