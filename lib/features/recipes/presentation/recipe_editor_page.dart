import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';

import '../data/admin_recipe_repository.dart';
import '../domain/recipe.dart';
import 'recipe_image.dart';
import '../../../core/theme/app_theme.dart';

class _IngredientForm {
  _IngredientForm({
    this.id,
    String? stepKey,
    String label = '',
    String quantity = '',
    this.unit = 'g',
  }) : key =
           stepKey ?? 'r${DateTime.now().microsecondsSinceEpoch}_${nextKey++}',
       name = TextEditingController(text: label),
       amount = TextEditingController(text: quantity);
  static int nextKey = 0;
  final String key;
  String? linkedText;
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
  final stepsFocus = FocusNode();
  final imageAddress = TextEditingController();
  final rows = <_IngredientForm>[];
  List<CatalogIngredient> catalog = [];
  bool published = false;
  String? imageUrl;
  int previousServings = 2;
  bool syncing = false;
  Set<String>? allergens;
  Set<String>? diets;
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
      imageUrl = existing.recipe.imageUrl;
      allergens = existing.recipe.verifiedAllergens?.toSet();
      diets = existing.recipe.verifiedDiets?.toSet();
      rows.addAll(
        existing.recipe.ingredients.map(
          (i) => _IngredientForm(
            id: i.ingredientId,
            stepKey: i.referenceKey,
            label: i.name,
            quantity: '${i.quantity}',
            unit: i.unit,
          ),
        ),
      );
    } else {
      rows.add(_IngredientForm());
    }
    previousServings = int.tryParse(servings.text) ?? 2;
    for (final row in rows) {
      watchIngredient(row);
    }
    for (final row in rows) {
      steps.text = steps.text.replaceAll(
        ingredientToken(row.key),
        '⟦${row.linkedText}⟧',
      );
    }
    servings.addListener(rescaleIngredients);
    loadIngredients();
  }

  Future<void> loadIngredients() async {
    setState(() => loading = true);
    try {
      final values = await widget.repository.ingredients();
      if (mounted) {
        setState(() {
          catalog = values;
          refreshLinkedSteps();
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
    stepsFocus.dispose();
    imageAddress.dispose();
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
    if (encodedSteps().contains('⟦') ||
        encodedSteps().contains('[Zutat entfernt]')) {
      setState(
        () => error = 'Bitte prüfe die Zutatenverknüpfungen in der Zubereitung. Entfernte oder bearbeitete Bausteine bitte löschen und erneut einfügen.',
      );
      return;
    }
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
        'image_url': imageUrl,
        'name': name.text.trim(),
        'minutes': int.parse(minutes.text),
        'servings': int.parse(servings.text),
        'steps': encodedSteps()
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'is_published': published,
        'verified_allergens': allergens?.toList(),
        'verified_diets': diets?.toList(),
        'ingredients': [
          for (final row in rows)
            {
              'ingredient_id': row.id,
              'step_key': row.key,
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

  String ingredientLabel(_IngredientForm row) {
    if (row.id == null) return row.name.text.trim();
    for (final item in catalog) {
      if (item.id == row.id) return item.name;
    }
    return row.name.text.trim();
  }

  String rowText(_IngredientForm row) {
    final quantity = amount(row.amount.text);
    if (quantity == null || !quantity.isFinite) {
      return '${row.amount.text} ${row.unit} ${ingredientLabel(row)}';
    }
    return ingredientText(
      IngredientAmount('', ingredientLabel(row), quantity, row.unit),
      1,
    );
  }

  void watchIngredient(_IngredientForm row) {
    row.linkedText = rowText(row);
    row.name.addListener(refreshLinkedSteps);
    row.amount.addListener(refreshLinkedSteps);
  }

  void refreshLinkedSteps() {
    if (syncing) return;
    var text = steps.text;
    for (final row in rows) {
      final next = rowText(row);
      if (row.linkedText != null) {
        text = text.replaceAll('⟦${row.linkedText}⟧', '⟦$next⟧');
      }
      row.linkedText = next;
    }
    if (text != steps.text) {
      final cursor = steps.selection.baseOffset.clamp(0, text.length);
      steps.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor),
      );
    }
  }

  void rescaleIngredients() {
    final next = int.tryParse(servings.text);
    if (next == null || next < 1 || next > 100 || next == previousServings) {
      return;
    }
    syncing = true;
    for (final row in rows) {
      final quantity = amount(row.amount.text);
      if (quantity != null && quantity.isFinite) {
        row.amount.text = (quantity * next / previousServings)
            .toStringAsFixed(4)
            .replaceFirst(RegExp(r'\.?0+$'), '')
            .replaceAll('.', ',');
      }
    }
    previousServings = next;
    syncing = false;
    refreshLinkedSteps();
  }

  String encodedSteps() {
    var text = steps.text;
    for (final row in rows) {
      text = text.replaceAll('⟦${row.linkedText}⟧', ingredientToken(row.key));
    }
    return text;
  }

  Future<void> changeImage() async {
    final controller = imageAddress;
    controller.text = imageUrl?.startsWith('https://') == true ? imageUrl! : '';
    String? validation;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Rezeptbild ändern'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Wähle ein vorhandenes Bild oder verwende eine öffentliche HTTPS-Bildadresse.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final asset in [
                        'assets/images/pasta.jpg',
                        'assets/images/rice.jpg',
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: InkWell(
                              onTap: () => Navigator.pop(context, asset),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  asset,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  semanticLabel: asset.contains('pasta')
                                      ? 'Pastabild auswählen'
                                      : 'Reisbild auswählen',
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('recipe-image-url'),
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Bildadresse (https://…)',
                      errorText: validation,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                final uri = Uri.tryParse(value);
                if (uri == null ||
                    uri.scheme != 'https' ||
                    uri.host.isEmpty ||
                    value.length > 2048 ||
                    RegExp(r'\s').hasMatch(value)) {
                  update(
                    () => validation =
                        'Bitte eine gültige HTTPS-Bildadresse eingeben.',
                  );
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('Bild übernehmen'),
            ),
          ],
        ),
      ),
    );
    // The closing dialog still owns its text field during the transition.
    if (mounted && selected != null) setState(() => imageUrl = selected);
  }

  Future<void> insertIngredient() async {
    final selection = steps.selection;
    final available = rows
        .where(
          (row) =>
              ingredientLabel(row).isNotEmpty &&
              (amount(row.amount.text)?.isFinite ?? false) &&
              (amount(row.amount.text) ?? 0) > 0,
        )
        .toList();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Zutat in den Text einfügen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Wähle eine Zutat aus deiner Zutatenliste. Menge und Einheit kommen direkt mit.',
                ),
                const SizedBox(height: 16),
                if (available.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Trage oben zuerst eine Zutat mit einer gültigen Menge ein.',
                    ),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final row in available)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.add_circle_outline),
                          title: Text(rowText(row)),
                          onTap: () =>
                              Navigator.pop(context, '⟦${rowText(row)}⟧'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || text == null) return;
    final value = steps.text;
    final start = selection.isValid
        ? selection.start.clamp(0, value.length)
        : value.length;
    final end = selection.isValid
        ? selection.end.clamp(start, value.length)
        : start;
    final before = value.substring(0, start);
    final after = value.substring(end);
    final prefix = before.isNotEmpty && !RegExp(r'[\s(\[]$').hasMatch(before)
        ? ' '
        : '';
    final suffix =
        after.isNotEmpty && !RegExp(r'^[\s.,;:!?\)\]]').hasMatch(after)
        ? ' '
        : '';
    final inserted = '$prefix$text$suffix';
    steps.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    stepsFocus.requestFocus();
  }

  Widget sectionCard(
    String number,
    String title,
    String description,
    List<Widget> children,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .12),
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    ),
  );

  Widget cover() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: name,
    builder: (context, value, _) {
      final title = value.text.trim();
      final pasta =
          title.toLowerCase().contains('pasta') ||
          title.toLowerCase().contains('nudeln');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                RecipeImage(
                  imageUrl ??
                      (pasta
                          ? 'assets/images/pasta.jpg'
                          : 'assets/images/rice.jpg'),
                  key: const ValueKey('editor-recipe-image'),
                  height: MediaQuery.sizeOf(context).width < 600 ? 220 : 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: 'Rezeptbild',
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      published ? 'Veröffentlicht' : 'Rezeptentwurf',
                      style: const TextStyle(
                        color: AppColors.sage,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            imageUrl?.startsWith('https://') == true
                ? 'Dein Rezeptbild'
                : 'Beispielbild · wie in der Rezeptansicht',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: changeImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Bild ändern'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.existing == null ? 'Dein neues Rezept.' : 'Feiner machen.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            title.isEmpty ? 'Aus guten Zutaten wird eine gute Idee.' : title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Zutaten, Zubereitung und geprüfte Angaben an einem Ort.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Neues Rezept' : 'Rezept bearbeiten',
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Zurück',
                onPressed: busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
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
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 16),
                    Text(error ?? 'Zutaten konnten nicht geladen werden.'),
                    const SizedBox(height: 16),
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
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Form(
                    key: form,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                        16,
                        MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                        40,
                      ),
                      children: [
                        if (error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        cover(),
                        sectionCard(
                          '01',
                          'Das Wichtigste',
                          'Gib deinem Rezept einen Namen und lege Zeit und Portionen fest.',
                          [
                            const SizedBox(height: 14),
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
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const ValueKey('recipe-minutes'),
                              controller: minutes,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Zubereitungszeit in Minuten',
                              ),
                              validator: (v) => positiveInteger(v, 1440),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const ValueKey('recipe-servings'),
                              controller: servings,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Basisportionen',
                              ),
                              validator: (v) => positiveInteger(v, 100),
                            ),
                          ],
                        ),
                        sectionCard(
                          '02',
                          'Gute Zutaten',
                          'Alle Mengen beziehen sich auf die angegebenen Basisportionen.',
                          [
                            for (var i = 0; i < rows.length; i++)
                              Card(
                                color: Theme.of(context)
                                    .scaffoldBackgroundColor,
                                elevation: 0,
                                key: ValueKey(rows[i]),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 4),
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
                                          rows[i].id = v == '__new__'
                                              ? null
                                              : v;
                                          refreshLinkedSteps();
                                        }),
                                      ),
                                      if (rows[i].id == null) ...[
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          key: ValueKey('ingredient-name-$i'),
                                          controller: rows[i].name,
                                          maxLength: 120,
                                          decoration: const InputDecoration(
                                            labelText: 'Name der neuen Zutat',
                                          ),
                                          validator: (v) =>
                                              (v ?? '').trim().isEmpty
                                              ? 'Bitte eine Zutat angeben.'
                                              : null,
                                        ),
                                      ],
                                      const SizedBox(height: 12),
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
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        initialValue: rows[i].unit,
                                        decoration: const InputDecoration(
                                          labelText: 'Einheit',
                                        ),
                                        items: [
                                          for (final unit in [
                                            'g',
                                            'ml',
                                            'Stück',
                                          ])
                                            DropdownMenuItem(
                                              value: unit,
                                              child: Text(unit),
                                            ),
                                        ],
                                        onChanged: (v) {
                                          rows[i].unit = v!;
                                          refreshLinkedSteps();
                                        },
                                      ),
                                      TextButton.icon(
                                        onPressed: rows.length < 2
                                            ? null
                                            : () => setState(() {
                                                final removed = rows.removeAt(
                                                  i,
                                                );
                                                steps.text = steps.text
                                                    .replaceAll(
                                                      '⟦${removed.linkedText}⟧',
                                                      '[Zutat entfernt]',
                                                    );
                                                removed.dispose();
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
                                  : () => setState(() {
                                      final row = _IngredientForm();
                                      watchIngredient(row);
                                      rows.add(row);
                                    }),
                              icon: const Icon(Icons.add),
                              label: const Text('Zutat hinzufügen'),
                            ),
                          ],
                        ),
                        sectionCard(
                          '03',
                          'Schritt für Schritt',
                          'Schreibe die Zubereitung und füge Zutaten mit Menge direkt an der Cursorposition ein.',
                          [
                            TextFormField(
                              key: const ValueKey('recipe-steps'),
                              controller: steps,
                              focusNode: stepsFocus,
                              minLines: 4,
                              maxLines: 10,
                              decoration: const InputDecoration(
                                labelText: 'Zubereitung',
                                helperText: 'Ein Schritt pro Zeile · Zutaten über „Zutat einfügen“ verknüpfen',
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
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: insertIngredient,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Zutat einfügen'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Eingefügte Zutatenbausteine aktualisieren Menge, Einheit und Name automatisch. Die Mengen skalieren mit den Basisportionen. Frei geschriebene Angaben bleiben unverändert.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        sectionCard(
                          '04',
                          'Bewusst geplant',
                          'Nur nach Prüfung aller Zutaten und der Zubereitung bestätigen. Die sechs Allergene entsprechen den Ausschlüssen der Planung und sind keine vollständige Allergenkennzeichnung.',
                          [
                            SwitchListTile(
                              title: const Text('Allergene geprüft'),
                              subtitle: const Text(
                                'Keine Auswahl: keines der aufgeführten Allergene enthalten.',
                              ),
                              value: allergens != null,
                              onChanged: (v) => setState(
                                () => allergens = v ? <String>{} : null,
                              ),
                            ),
                            if (allergens != null)
                              for (final value in planningAllergens)
                                CheckboxListTile(
                                  title: Text(value),
                                  value: allergens!.contains(value),
                                  onChanged: (selected) => setState(() {
                                    if (selected == true) {
                                      allergens!.add(value);
                                    } else {
                                      allergens!.remove(value);
                                    }
                                  }),
                                ),
                            SwitchListTile(
                              title: const Text('Ernährungsweisen geprüft'),
                              subtitle: const Text(
                                'Alle zutreffenden Angaben auswählen. Vegan schließt vegetarisch ein.',
                              ),
                              value: diets != null,
                              onChanged: (v) =>
                                  setState(() => diets = v ? <String>{} : null),
                            ),
                            if (diets != null)
                              for (final value in planningDiets)
                                CheckboxListTile(
                                  title: Text(value),
                                  value: diets!.contains(value),
                                  onChanged: (selected) => setState(() {
                                    if (selected == true) {
                                      diets!.add(value);
                                      if (value == 'Vegan') {
                                        diets!.add('Vegetarisch');
                                      }
                                    } else {
                                      diets!.remove(value);
                                      if (value == 'Vegetarisch') {
                                        diets!.remove('Vegan');
                                      }
                                    }
                                  }),
                                ),
                          ],
                        ),
                        sectionCard(
                          '05',
                          'Bereit zum Teilen?',
                          'Speichere einen Entwurf oder gib das Rezept für den Katalog frei.',
                          [
                            SwitchListTile(
                              title: const Text('Veröffentlicht'),
                              subtitle: const Text(
                                'Veröffentlichte Rezepte erscheinen im öffentlichen Katalog.',
                              ),
                              value: published,
                              onChanged: (v) => setState(() => published = v),
                            ),
                          ],
                        ),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: LinearProgressIndicator(),
                          ),
                        FilledButton.icon(
                          onPressed: busy ? null : save,
                          icon: const Icon(Icons.check),
                          label: Text(
                            busy ? 'Wird gespeichert …' : 'Rezept speichern',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Deine Änderungen werden beim Speichern übernommen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
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
