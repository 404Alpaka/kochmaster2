import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';

import '../data/admin_recipe_repository.dart';

class _IngredientForm {
  _IngredientForm({
    this.id,
    String label = '',
    String quantity = '',
    this.unit = 'g',
  }) : name = TextEditingController(text: label),
       amount = TextEditingController(text: quantity);
  String? id;
  String unit;
  final TextEditingController name;
  final TextEditingController amount;
  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({super.key, required this.repository, this.existing});
  final AdminRecipeRepository repository;
  final AdminRecipe? existing;
  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final minutes = TextEditingController(text: '30');
  final servings = TextEditingController(text: '2');
  final steps = TextEditingController();
  final rows = <_IngredientForm>[];
  List<CatalogIngredient> catalog = [];
  bool published = false;
  bool loading = true;
  bool catalogReady = false;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      name.text = existing.recipe.name;
      minutes.text = '${existing.recipe.minutes}';
      servings.text = '${existing.recipe.servings}';
      steps.text = existing.recipe.steps.join('\n');
      published = existing.published;
      rows.addAll(
        existing.recipe.ingredients.map(
          (i) => _IngredientForm(
            id: i.ingredientId,
            label: i.name,
            quantity: '${i.quantity}',
            unit: i.unit,
          ),
        ),
      );
    } else {
      rows.add(_IngredientForm());
    }
    loadIngredients();
  }

  Future<void> loadIngredients() async {
    setState(() => loading = true);
    try {
      final values = await widget.repository.ingredients();
      if (mounted) {
        setState(() {
          catalog = values;
          catalogReady = true;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Zutaten konnten nicht geladen werden. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    minutes.dispose();
    servings.dispose();
    steps.dispose();
    for (final row in rows) {
      row.dispose();
    }
    super.dispose();
  }

  String? positiveInteger(String? value, int max) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 1 || number > max
        ? 'Bitte eine ganze Zahl von 1 bis $max eingeben.'
        : null;
  }

  double? amount(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final unique = <String>{};
    for (final row in rows) {
      final key = '${row.id ?? row.name.text.trim().toLowerCase()}|${row.unit}';
      if (!unique.add(key)) {
        setState(
          () => error = 'Eine Zutat mit derselben Einheit ist mehrfach vorhanden. Bitte Mengen zusammenfassen.',
        );
        return;
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.save({
        'id': widget.existing?.recipe.id,
        'name': name.text.trim(),
        'minutes': int.parse(minutes.text),
        'servings': int.parse(servings.text),
        'steps': steps.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'is_published': published,
        'ingredients': [
          for (final row in rows)
            {
              'ingredient_id': row.id,
              'name': row.name.text.trim(),
              'quantity': amount(row.amount.text),
              'unit': row.unit,
            },
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(
          () => error = e.code == '42501'
              ? 'Deinem Konto fehlen die Admin-Rechte.'
              : e.code == '23505'
              ? 'Eine Zutat mit derselben Einheit ist mehrfach vorhanden. Bitte fasse die Mengen zusammen.'
              : 'Rezept konnte nicht gespeichert werden. Prüfe Zutaten und Mengen; vorhandene Daten bleiben erhalten.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Speichern fehlgeschlagen. Bitte prüfe deine Verbindung und versuche es erneut.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Neues Rezept' : 'Rezept bearbeiten',
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : !catalogReady
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error ?? 'Zutaten konnten nicht geladen werden.'),
                    FilledButton(
                      onPressed: loadIngredients,
                      child: const Text('Zutaten erneut laden'),
                    ),
                  ],
                ),
              ),
            )
          : AbsorbPointer(
              absorbing: busy,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(
                    key: form,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (catalog.isEmpty && error != null)
                          TextButton(
                            onPressed: loadIngredients,
                            child: const Text('Zutaten erneut laden'),
                          ),
                        TextFormField(
                          key: const ValueKey('recipe-name'),
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Rezeptname',
                          ),
                          maxLength: 160,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Bitte einen Rezeptnamen eingeben.'
                              : null,
                        ),
                        TextFormField(
                          key: const ValueKey('recipe-minutes'),
                          controller: minutes,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Zubereitungszeit in Minuten',
                          ),
                          validator: (v) => positiveInteger(v, 1440),
                        ),
                        TextFormField(
                          key: const ValueKey('recipe-servings'),
                          controller: servings,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Basisportionen',
                          ),
                          validator: (v) => positiveInteger(v, 100),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Zutaten',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (var i = 0; i < rows.length; i++)
                          Card(
                            key: ValueKey(rows[i]),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: rows[i].id ?? '__new__',
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Zutat auswählen',
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: '__new__',
                                        child: Text('Neue Zutat anlegen'),
                                      ),
                                      for (final ingredient in catalog)
                                        DropdownMenuItem(
                                          value: ingredient.id,
                                          child: Text(ingredient.name),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() {
                                      rows[i].id = v == '__new__' ? null : v;
                                    }),
                                  ),
                                  if (rows[i].id == null)
                                    TextFormField(
                                      key: ValueKey('ingredient-name-$i'),
                                      controller: rows[i].name,
                                      maxLength: 120,
                                      decoration: const InputDecoration(
                                        labelText: 'Name der neuen Zutat',
                                      ),
                                      validator: (v) => (v ?? '').trim().isEmpty
                                          ? 'Bitte eine Zutat angeben.'
                                          : null,
                                    ),
                                  TextFormField(
                                    key: ValueKey('ingredient-amount-$i'),
                                    controller: rows[i].amount,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Menge',
                                    ),
                                    validator: (v) {
                                      final n = amount(v ?? '');
                                      return n == null ||
                                              !n.isFinite ||
                                              n <= 0 ||
                                              n > 1000000
                                          ? 'Bitte eine Menge größer als 0 eingeben.'
                                          : null;
                                    },
                                  ),
                                  DropdownButtonFormField<String>(
                                    initialValue: rows[i].unit,
                                    decoration: const InputDecoration(
                                      labelText: 'Einheit',
                                    ),
                                    items: [
                                      for (final unit in ['g', 'ml', 'Stück'])
                                        DropdownMenuItem(
                                          value: unit,
                                          child: Text(unit),
                                        ),
                                    ],
                                    onChanged: (v) => rows[i].unit = v!,
                                  ),
                                  TextButton.icon(
                                    onPressed: rows.length < 2
                                        ? null
                                        : () => setState(() {
                                            rows.removeAt(i).dispose();
                                          }),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    label: const Text('Zutat entfernen'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: rows.length >= 100
                              ? null
                              : () =>
                                    setState(() => rows.add(_IngredientForm())),
                          icon: const Icon(Icons.add),
                          label: const Text('Zutat hinzufügen'),
                        ),
                        TextFormField(
                          key: const ValueKey('recipe-steps'),
                          controller: steps,
                          minLines: 4,
                          maxLines: 10,
                          decoration: const InputDecoration(
                            labelText: 'Zubereitung',
                            helperText: 'Ein Schritt pro Zeile',
                          ),
                          validator: (v) {
                            final lines = (v ?? '')
                                .split('\n')
                                .where((s) => s.trim().isNotEmpty)
                                .toList();
                            return lines.isEmpty
                                ? 'Bitte mindestens einen Zubereitungsschritt eingeben.'
                                : lines.length > 100 ||
                                      lines.any((s) => s.length > 5000)
                                ? 'Zubereitung zu lang. Maximal 100 Schritte mit je 5000 Zeichen.'
                                : null;
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Veröffentlicht'),
                          subtitle: const Text(
                            'Veröffentlichte Rezepte erscheinen im öffentlichen Katalog.',
                          ),
                          value: published,
                          onChanged: (v) => setState(() => published = v),
                        ),
                        const SizedBox(height: 16),
                        if (busy) const LinearProgressIndicator(),
                        FilledButton.icon(
                          onPressed: busy ? null : save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            busy ? 'Wird gespeichert …' : 'Rezept speichern',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}
