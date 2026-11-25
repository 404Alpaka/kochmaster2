import 'package:material_ui/material_ui.dart';

import '../features/recipes/domain/recipe.dart';
import '../features/recipes/data/cached_recipe_repository.dart';

class RecipeLoader extends StatefulWidget {
  const RecipeLoader({
    super.key,
    required this.repository,
    required this.builder,
  });
  final RecipeRepository repository;
  final Widget Function(List<Recipe>) builder;
  @override
  State<RecipeLoader> createState() => _RecipeLoaderState();
}

class _RecipeLoaderState extends State<RecipeLoader> {
  late Future<List<Recipe>> result;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    result = Future.sync(widget.repository.getAll);
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    return repository is CachedRecipeRepository
        ? ValueListenableBuilder<CatalogSnapshot?>(
            valueListenable: repository.snapshot,
            builder: (context, cached, _) => contents(cached),
          )
        : contents(null);
  }

  Widget contents(CatalogSnapshot? cached) => FutureBuilder<List<Recipe>>(
    future: result,
    builder: (context, snapshot) {
      final recipes = cached?.recipes ?? snapshot.data;
      if (recipes != null) {
        return Column(
          children: [
            if (cached?.offline == true)
              MaterialBanner(
                content: const Text(
                  'Rezepte sind offline verfügbar. Angezeigt wird der zuletzt gespeicherte Katalog; Bilder können fehlen.',
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await (widget.repository as CachedRecipeRepository)
                            .refresh();
                      } catch (_) {
                        /* Keep the last usable catalog visible. */
                      }
                    },
                    child: const Text('Aktualisieren'),
                  ),
                ],
              ),
            Expanded(child: widget.builder(recipes)),
          ],
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Kochmaster')),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Rezepte konnten nicht geladen werden.'),
                    const Text('Prüfe Verbindung und Datenbankkonfiguration.'),
                    FilledButton(
                      onPressed: () => setState(load),
                      child: const Text('Erneut versuchen'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
