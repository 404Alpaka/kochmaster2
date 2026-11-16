import 'package:material_ui/material_ui.dart';

import '../features/recipes/domain/recipe.dart';

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
  Widget build(BuildContext context) => FutureBuilder<List<Recipe>>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.hasData) return widget.builder(snapshot.data!);
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
