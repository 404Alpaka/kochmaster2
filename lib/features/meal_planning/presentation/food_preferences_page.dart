import 'package:material_ui/material_ui.dart';

import '../../recipes/domain/recipe.dart';

class FoodPreferences {
  const FoodPreferences({
    required this.diet,
    required this.exclusions,
    required this.servings,
    required this.days,
    required this.minutes,
    required this.budget,
  });
  final String diet;
  final Set<String> exclusions;
  final int servings, days, minutes;
  final double? budget;
}

class FoodPreferencesPage extends StatefulWidget {
  const FoodPreferencesPage({super.key, required this.initial});
  final FoodPreferences initial;
  @override
  State<FoodPreferencesPage> createState() => _FoodPreferencesPageState();
}

class _FoodPreferencesPageState extends State<FoodPreferencesPage> {
  final form = GlobalKey<FormState>();
  late String diet = widget.initial.diet;
  late final exclusions = {...widget.initial.exclusions};
  late int servings = widget.initial.servings;
  late int days = widget.initial.days;
  late int minutes = widget.initial.minutes;
  late bool limitBudget = widget.initial.budget != null;
  late final budget = TextEditingController(
    text: (widget.initial.budget ?? 75).toStringAsFixed(2).replaceAll('.', ','),
  );
  @override
  void dispose() {
    budget.dispose();
    super.dispose();
  }

  Widget section(String title, String hint, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(hint),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Essenspräferenzen')),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Präferenzen übernehmen'),
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(
              context,
              FoodPreferences(
                diet: diet,
                exclusions: exclusions,
                servings: servings,
                days: days,
                minutes: minutes,
                budget: limitBudget
                    ? double.parse(budget.text.trim().replaceAll(',', '.'))
                    : null,
              ),
            );
          },
        ),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const Text(
                'So soll dein Wochenplan zu dir passen. Deine Angaben gelten für neue Rezeptvorschläge.',
              ),
              const SizedBox(height: 16),
              section(
                'Deine Ernährungsweise',
                'Was kommt bei dir auf den Teller?',
                [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in [
                        'Ohne Einschränkung',
                        ...planningDiets,
                      ])
                        ChoiceChip(
                          label: Text(value),
                          selected: diet == value,
                          onSelected: (_) => setState(() => diet = value),
                        ),
                    ],
                  ),
                ],
              ),
              section(
                'Allergene ausschließen',
                'Für ausgewählte Ausschlüsse werden nur Rezepte mit passenden geprüften Angaben vorgeschlagen.',
                [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final allergen in planningAllergens)
                        FilterChip(
                          label: Text(allergen),
                          selected: exclusions.contains(allergen),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              exclusions.add(allergen);
                            } else {
                              exclusions.remove(allergen);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
              section(
                'Personen & Tage',
                'Für wie viele Personen und Abendessen planst du?',
                [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$servings ${servings == 1 ? 'Person' : 'Personen'}',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Weniger Personen',
                        onPressed: servings > 1
                            ? () => setState(() => servings--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        tooltip: 'Mehr Personen',
                        onPressed: servings < 30
                            ? () => setState(() => servings++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final count in ([
                        ...{3, 5, 7, days},
                      ]..sort()))
                        ChoiceChip(
                          label: Text('$count Tage'),
                          selected: days == count,
                          onSelected: (_) => setState(() => days = count),
                        ),
                    ],
                  ),
                ],
              ),
              section('Zeit zum Kochen', 'Wie lange darf ein Gericht dauern?', [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final count in {
                      ...[15, 30, 45, 60, 0],
                      minutes,
                    })
                      ChoiceChip(
                        label: Text(count == 0 ? 'Flexibel' : '$count Min.'),
                        selected: minutes == count,
                        onSelected: (_) => setState(() => minutes = count),
                      ),
                  ],
                ),
              ]),
              section(
                'Dein Wochenbudget',
                'Dein Ziel für die geplanten Abendessen.',
                [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Budget festlegen'),
                    value: limitBudget,
                    onChanged: (value) => setState(() => limitBudget = value),
                  ),
                  if (limitBudget)
                    TextFormField(
                      key: const ValueKey('food-preferences-budget'),
                      controller: budget,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      textInputAction: TextInputAction.done,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Budget pro Woche',
                        suffixText: '€',
                      ),
                      validator: (value) {
                        final n = double.tryParse(
                          (value ?? '').trim().replaceAll(',', '.'),
                        );
                        return n == null || !n.isFinite || n < 5 || n > 10000
                            ? 'Bitte ein Budget zwischen 5 und 10.000 € eingeben.'
                            : null;
                      },
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    'Das Budget ist ein Planungsziel. Eine Prüfung anhand aktueller Produktpreise ist noch nicht verfügbar.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
