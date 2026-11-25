part of 'planning_page.dart';

extension _CookingViews on _PlanningPageState {
  Future<void> persistCookingProgress({bool clear = false}) async {
    final snapshot = !clear && cookingSession.recipe != null
        ? jsonEncode(
            CookingProgress(
              recipe: cookingSession.recipe!,
              portions: cookingSession.portions,
              step: cookingSession.step,
              key: cookingSession.key,
              date: cookingSession.date ?? pantryToday,
              day: cookingSession.day,
              timers: Map<int, CookingTimer>.from(cookingSession.timers),
            ).toJson(),
          )
        : null;
    final operation = cookingProgressWrite.then((_) async {
      if (snapshot == null) {
        await cookingProgressStore.remove(cookingProgressKey);
      } else {
        await cookingProgressStore.setString(cookingProgressKey, snapshot);
      }
    });
    cookingProgressWrite = operation.catchError((Object _) {});
    try {
      await operation;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Der Kochfortschritt konnte nicht lokal gespeichert werden.',
            ),
          ),
        );
      }
    }
  }

  void showCookingProgressMessage(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Future<void> restoreCookingProgress() async {
    String? raw;
    try {
      raw = await cookingProgressStore.getString(cookingProgressKey);
    } catch (_) {
      if (mounted) {
        showCookingProgressMessage(
          'Der lokale Kochfortschritt konnte nicht geladen werden.',
        );
      }
      return;
    }
    if (raw == null || !mounted || cookingSession.recipe != null) return;

    late CookingProgress progress;
    try {
      progress = CookingProgress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      try {
        await cookingProgressStore.remove(cookingProgressKey);
      } catch (_) {
        // Keep the invalid entry for inspection if storage is unavailable.
      }
      if (mounted) {
        showCookingProgressMessage(
          'Der gespeicherte Kochfortschritt war ungültig und wurde verworfen.',
        );
      }
      return;
    }

    try {
      if (cookingSession.cookedEntries.contains(progress.key)) {
        await cookingProgressStore.remove(cookingProgressKey);
        return;
      }
      var restoredRecipe = progress.recipe;
      for (final recipe in recipes) {
        if (recipe.id == progress.recipe.id) {
          restoredRecipe = recipe;
          break;
        }
      }
      final validTimers = <int, CookingTimer>{
        for (final entry in progress.timers.entries)
          if (entry.key >= 0 && entry.key < restoredRecipe.steps.length)
            entry.key: entry.value,
      };
      update(() {
        cookingSession.recipe = restoredRecipe;
        cookingSession.portions = progress.portions.clamp(1, 30).toInt();
        cookingSession.step = progress.step
            .clamp(0, (restoredRecipe.steps.length - 1).clamp(0, 100000))
            .toInt();
        cookingSession.date = progress.date;
        cookingSession.day = progress.day;
        cookingSession.key = progress.key;
        cookingSession.page = 0;
        cookingSession.timers
          ..clear()
          ..addAll(validTimers);
        cookingSession.uses.clear();
      });
      startCookingTicker();
    } catch (_) {
      if (mounted) {
        showCookingProgressMessage(
          'Der Kochfortschritt konnte nicht wiederhergestellt werden.',
        );
      }
    }
  }

  void startCookingTicker() {
    cookingSession.ticker?.cancel();
    checkCookingTimers();
    cookingSession.ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      checkCookingTimers();
    });
  }

  void checkCookingTimers() {
    if (!mounted || cookingSession.recipe == null) return;
    final ended = <int>[];
    for (final entry in cookingSession.timers.entries) {
      if (entry.value.started &&
          entry.value.deadline != null &&
          entry.value.remaining == 0 &&
          !entry.value.announced) {
        entry.value.announced = true;
        ended.add(entry.key);
      }
    }
    if (cookingSession.timers.values.any((timer) => timer.running) ||
        ended.isNotEmpty) {
      update(() {});
    }
    if (ended.isNotEmpty) {
      unawaited(persistCookingProgress());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Timer beendet: Schritt ${ended.map((i) => i + 1).join(', ')}.',
          ),
        ),
      );
      for (final step in ended) {
        unawaited(CookingRuntime.showTimerNotification(step));
      }
    }
  }

  Future<void> cancelCooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kochvorgang abbrechen?'),
        content: const Text(
          'Der Kochfortschritt und alle Timer werden beendet. Vorräte und übrige Portionen bleiben unverändert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Weiterkochen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kochvorgang abbrechen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    cookingSession.ticker?.cancel();
    update(() {
      cookingSession.recipe = null;
      cookingSession.page = 0;
      cookingSession.step = 0;
      cookingSession.portions = servings;
      cookingSession.day = null;
      cookingSession.date = null;
      cookingSession.key = '';
      cookingSession.timers.clear();
      cookingSession.uses.clear();
    });
    await persistCookingProgress(clear: true);
    unawaited(CookingRuntime.disableKeepScreenOn());
  }

  List<Widget> cookingFlow() => cookingSession.recipe == null
      ? []
      : switch (cookingSession.page) {
          2 => cookingStepView(),
          3 => cookingFinishedView(),
          _ => cookingOverview(),
        };
  String timerLabel(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  List<IngredientAmount> get cookingIngredients => buildShoppingList([
    PlannedMeal(cookingSession.recipe!, cookingSession.portions),
  ]);

  Future<void> openCooking(
    Recipe recipe, {
    required int portions,
    int? day,
  }) async {
    if (readOnlyShared) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dieser Haushalt ist für dich nur lesbar.'),
        ),
      );
      return;
    }
    final date = day == null ? pantryToday : week.add(Duration(days: day));
    final key = '${dateKey(date)}:${recipe.id}';
    if (cookingSession.recipe != null &&
        cookingSession.key == key &&
        !cookingSession.cookedEntries.contains(key)) {
      update(() => cookingSession.page = cookingSession.step > 0 ? 2 : 1);
      unawaited(CookingRuntime.enableKeepScreenOn());
      return;
    }
    if (cookingSession.recipe != null &&
        !cookingSession.cookedEntries.contains(cookingSession.key)) {
      final change = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kochvorgang wechseln?'),
          content: const Text(
            'Der bisherige Kochfortschritt und seine Timer werden beendet. Vorräte bleiben unverändert.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Wechseln'),
            ),
          ],
        ),
      );
      if (change != true || !mounted) return;
    }
    cookingSession.ticker?.cancel();
    update(() {
      cookingSession.recipe = recipe;
      cookingSession.portions = portions;
      cookingSession.day = day;
      cookingSession.date = date;
      cookingSession.key = key;
      cookingSession.page = 1;
      cookingSession.step = 0;
      cookingSession.timers.clear();
      cookingSession.uses.clear();
      cookingSession.remainingCookedPortions = (portions - servings)
          .clamp(0, portions)
          .toInt();
      cookingSession.cookedOn = pantryToday;
      cookingSession.cookedStorage = 'Kühlschrank';
    });
    unawaited(CookingRuntime.enableKeepScreenOn());
    startCookingTicker();
    unawaited(persistCookingProgress());
  }

  Widget cookingPortionControl() => Row(
    children: [
      IconButton(
        tooltip: 'Weniger Kochportionen',
        onPressed: cookingSession.portions <= 1
            ? null
            : () {
                update(() => cookingSession.portions--);
                unawaited(persistCookingProgress());
              },
        icon: const Icon(Icons.remove),
      ),
      Expanded(
        child: Text(
          '${cookingSession.portions} Portionen',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      IconButton(
        tooltip: 'Mehr Kochportionen',
        onPressed: cookingSession.portions >= 30
            ? null
            : () {
                update(() => cookingSession.portions++);
                unawaited(persistCookingProgress());
              },
        icon: const Icon(Icons.add),
      ),
    ],
  );
  List<Widget> cookingOverview() => [
    proposalBack(
      cookingSession.day == null
          ? 'Zurück zum Rezept'
          : 'Zurück zum Wochenplan',
      () => update(() => cookingSession.page = 0),
    ),
    gap(14),
    title('Zeit zu kochen.'),
    gap(12),
    Text(
      '${cookingSession.day == null ? 'Heute' : _PlanningPageState.days[cookingSession.day!]} · ${displayDate(cookingSession.date!)}${cookingSession.day == null ? '' : ' · aus deinem Plan'}',
      style: muted,
    ),
    gap(18),
    surveyCard(
      cookingSession.recipe!.name,
      mealDescription(cookingSession.recipe!, cookingSession.portions),
    ),
    gap(18),
    if (cookingSession.cookedEntries.contains(cookingSession.key)) ...[
      surveyCard(
        '✓ Bereits als gekocht gespeichert',
        'Dieser Kochvorgang wurde abgeschlossen. Vorräte und Reste werden kein zweites Mal gebucht.',
        color: AppColors.softGreen,
      ),
      gap(18),
    ] else ...[
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Heute mehr kochen, morgen weniger tun.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            gap(10),
            cookingPortionControl(),
            gap(10),
            Text(
              'Die Zutaten werden für ${cookingSession.portions} Portionen berechnet. Übrige Portionen legst du nach dem Kochen fest.',
              style: muted,
            ),
          ],
        ),
        color: AppColors.softGreen,
      ),
      gap(18),
    ],
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('Das brauchst du'),
          for (final i in cookingIngredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${amountLabel(i.quantity, i.unit)} ${i.name}'),
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    ),
    gap(18),
    for (var i = 0; i < cookingSession.recipe!.steps.length; i++)
      TextButton(
        style: TextButton.styleFrom(alignment: Alignment.centerLeft),
        onPressed: cookingSession.cookedEntries.contains(cookingSession.key)
            ? null
            : () {
                update(() {
                  cookingSession.step = i;
                  cookingSession.page = 2;
                });
                unawaited(persistCookingProgress());
              },
        child: Text(
          '${i + 1}  ${renderRecipeStep(cookingSession.recipe!, cookingSession.recipe!.steps[i], portions: cookingSession.portions)}',
        ),
      ),
    if (cookingSession.recipe!.steps.isEmpty)
      Text(
        'Für dieses Gericht sind noch keine Zubereitungsschritte hinterlegt.',
        style: muted,
      ),
    gap(14),
    Text(
      'Rezepttexte bleiben unverändert. Mengenangaben innerhalb eines Kochschritts beziehen sich gegebenenfalls auf die Originalportionen; maßgeblich ist deine skalierte Zutatenliste.',
      style: muted,
    ),
    if (cookingSession.timers.isNotEmpty) ...[gap(14), ...cookingTimerCards()],
  ];

  CookingTimer stepTimer(int index) => cookingSession.timers.putIfAbsent(
    index,
    () {
      final match = RegExp(
        r'(\d+)\s*(?:Minuten|Min\.|Min\b)',
        caseSensitive: false,
      ).firstMatch(cookingSession.recipe!.steps[index]);
      return CookingTimer(
        ((int.tryParse(match?.group(1) ?? '') ?? 5).clamp(1, 180).toInt()) * 60,
      );
    },
  );
  List<Widget> cookingTimerCards() => [
    for (final entry in cookingSession.timers.entries) ...[
      cookingTimerCard(entry.key, entry.value),
      gap(14),
    ],
  ];
  Widget cookingTimerCard(int index, CookingTimer timer) {
    final dark = timer.running;
    final color = dark ? Colors.white : AppColors.lightText;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SCHRITT ${index + 1} · ${timer.running
                ? 'TIMER LÄUFT'
                : timer.started && timer.remaining == 0
                ? 'TIMER BEENDET'
                : timer.started
                ? 'PAUSIERT'
                : 'TIMER BEREIT'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          gap(10),
          Text(
            timerLabel(timer.remaining),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          gap(8),
          Text(
            'Dauer selbst prüfen und bei Bedarf anpassen.',
            style: TextStyle(fontSize: 13, color: color),
          ),
          gap(12),
          Row(
            children: [
              Expanded(
                child: recipeAction(
                  timer.running
                      ? 'Pause'
                      : timer.started && timer.remaining > 0
                      ? 'Fortsetzen'
                      : 'Starten',
                  false,
                  () {
                    update(timer.toggle);
                    unawaited(persistCookingProgress());
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: recipeAction('+ 1 Min.', false, () {
                  update(timer.addMinute);
                  unawaited(persistCookingProgress());
                }),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              update(timer.reset);
              unawaited(persistCookingProgress());
            },
            child: Text('Zurücksetzen', style: TextStyle(color: color)),
          ),
        ],
      ),
      color: dark ? AppColors.sage : AppColors.softGreen,
      padding: const EdgeInsets.all(20),
    );
  }

  List<Widget> cookingStepView() {
    final steps = renderedRecipeSteps(
      cookingSession.recipe!,
      portions: cookingSession.portions,
    );
    if (steps.isEmpty) return cookingOverview();
    final timer = stepTimer(cookingSession.step);
    return [
      proposalBack('Kochübersicht', () {
        update(() => cookingSession.page = 1);
        unawaited(persistCookingProgress());
      }),
      gap(16),
      Row(
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Container(
                height: 5,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: i <= cookingSession.step
                      ? AppColors.sage
                      : AppColors.softGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
      gap(18),
      Text(
        'SCHRITT ${cookingSession.step + 1} VON ${steps.length}',
        style: const TextStyle(
          color: AppColors.sage,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      gap(18),
      title(
        steps[cookingSession.step].length <= 65
            ? steps[cookingSession.step]
            : 'Schritt ${cookingSession.step + 1}',
      ),
      gap(14),
      if (steps[cookingSession.step].length > 65) ...[
        Text(
          steps[cookingSession.step],
          style: const TextStyle(fontSize: 18, height: 1.5),
        ),
        gap(18),
      ],
      cookingTimerCard(cookingSession.step, timer),
      gap(18),
      if (cookingSession.timers.entries.any(
        (e) => e.key != cookingSession.step && e.value.started,
      )) ...[
        section('Andere Timer im Blick'),
        for (final e in cookingSession.timers.entries.where(
          (e) => e.key != cookingSession.step && e.value.started,
        ))
          ListTile(
            title: Text(
              'Schritt ${e.key + 1} · ${timerLabel(e.value.remaining)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              update(() => cookingSession.step = e.key);
              unawaited(persistCookingProgress());
            },
          ),
        gap(14),
      ],
      if (cookingSession.step > 0)
        TextButton(
          onPressed: () {
            update(() => cookingSession.step--);
            unawaited(persistCookingProgress());
          },
          child: const Text('Vorheriger Schritt'),
        ),
      surveyCard(
        'Zutaten für ${cookingSession.portions} Portionen',
        cookingIngredients
            .map((i) => '${amountLabel(i.quantity, i.unit)} ${i.name}')
            .join('\n'),
      ),
      gap(14),
      Text(
        'Timer laufen beim Schrittwechsel weiter. Beim Verlassen bleibt der Kochvorgang gespeichert und kann später fortgesetzt werden.',
        style: muted,
      ),
    ];
  }

  void prepareCookingReview() {
    cookingSession.uses.clear();
    final ingredients = cookingIngredients;
    for (final ingredient in ingredients) {
      var needed = ingredient.quantity;
      for (final item in pantry) {
        final parsed = pantryAmount(item);
        final id = item['ingredientId'] as String?;
        final name = pantryName(item['name'] as String);
        final matchesIngredient = id != null
            ? id == ingredient.ingredientId
            : name == pantryName(ingredient.name) &&
                  ingredients
                          .where((i) => pantryName(i.name) == name)
                          .map((i) => i.ingredientId)
                          .toSet()
                          .length ==
                      1;
        if (parsed == null ||
            !matchesIngredient ||
            parsed.$2.toLowerCase() != ingredient.unit.toLowerCase() ||
            needed <= 0) {
          continue;
        }
        CookingUse? previous;
        for (final use in cookingSession.uses) {
          if (identical(use.item, item)) previous = use;
        }
        final available = parsed.$1 - (previous?.used ?? 0);
        final used = needed < available ? needed : available;
        if (used > 0) {
          if (previous == null) {
            cookingSession.uses.add(CookingUse(item, used, parsed.$2));
          } else {
            previous.used += used;
          }
          needed -= used;
        }
      }
    }
    update(() {
      cookingSession.deductStock = true;
      cookingSession.remainingCookedPortions =
          (cookingSession.portions - servings)
              .clamp(0, cookingSession.portions)
              .toInt();
      cookingSession.cookedOn = pantryToday;
      cookingSession.page = 3;
    });
    unawaited(persistCookingProgress());
  }

  Future<void> editCookingUse(CookingUse use) async {
    var value = amountLabel(use.used, '').trim();
    final form = GlobalKey<FormState>();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${use.item['name']} · Verbrauch'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Verbraucht in ${use.unit}'),
            onChanged: (v) => value = v,
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll(',', '.'));
              final available = pantryAmount(use.item)?.$1 ?? 0;
              return n == null || !n.isFinite || n < 0 || n > available
                  ? 'Bitte 0 bis $available eingeben.'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  double.parse(value.replaceAll(',', '.')),
                );
              }
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (result != null && mounted) update(() => use.used = result);
  }

  List<Widget> cookingFinishedView() => [
    proposalBack('Zurück zur Kochübersicht', () {
      update(() => cookingSession.page = 1);
      unawaited(persistCookingProgress());
    }),
    gap(14),
    const Text(
      '✓ Kochschritte abgeschlossen',
      style: TextStyle(color: AppColors.sage, fontWeight: FontWeight.w600),
    ),
    gap(12),
    title('Gekocht. Gut genutzt.'),
    gap(12),
    Text(
      '${cookingSession.recipe!.name} · ${cookingSession.portions} Portionen',
    ),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Verbrauchte Mengen übernehmen'),
            subtitle: const Text('Vorschläge prüfen und bei Bedarf anpassen.'),
            value: cookingSession.deductStock,
            onChanged: (v) =>
                update(() => cookingSession.deductStock = v ?? false),
          ),
          if (cookingSession.uses.isEmpty)
            Text(
              'Keine vorhandenen Vorräte eindeutig mit vergleichbaren Mengen zugeordnet. Es werden keine Mengen abgezogen.',
              style: muted,
            ),
          for (final use in cookingSession.uses) ...[
            Text(
              use.item['name'] as String,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () => editCookingUse(use),
              child: Text(
                '${amountLabel(use.used, use.unit)} verbraucht · Ändern',
              ),
            ),
            Text(
              '${use.item['amount']} → ${amountLabel(((pantryAmount(use.item)?.$1 ?? 0) - (cookingSession.deductStock ? use.used : 0)).clamp(0, double.infinity).toDouble(), use.unit)}',
              style: muted,
            ),
            gap(12),
          ],
          Text(
            'Vergleichbare Mengen werden umgerechnet, zum Beispiel Kilogramm in Gramm. Fehlende Zutaten und unbekannte Packungsinhalte werden nicht automatisch abgezogen.',
            style: muted,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    ),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('Übrige Portionen aufheben'),
          Row(
            children: [
              IconButton(
                onPressed: cookingSession.remainingCookedPortions > 0
                    ? () =>
                          update(() => cookingSession.remainingCookedPortions--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '${cookingSession.remainingCookedPortions} Portionen',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    cookingSession.remainingCookedPortions <
                        cookingSession.portions
                    ? () =>
                          update(() => cookingSession.remainingCookedPortions++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          gap(12),
          DropdownButtonFormField<String>(
            initialValue: cookingSession.cookedStorage,
            decoration: const InputDecoration(labelText: 'Aufbewahrung'),
            items: [
              for (final place in ['Kühlschrank', 'Gefrierfach'])
                DropdownMenuItem(value: place, child: Text(place)),
            ],
            onChanged: (v) {
              if (v != null) update(() => cookingSession.cookedStorage = v);
            },
          ),
          gap(12),
          TextButton.icon(
            icon: const Icon(Icons.event_outlined),
            label: Text(
              'Gekocht am: ${displayDate(cookingSession.cookedOn ?? pantryToday)}',
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: cookingSession.cookedOn ?? pantryToday,
                firstDate: DateTime(2000),
                lastDate: pantryToday,
              );
              if (date != null && mounted)
                update(() => cookingSession.cookedOn = date);
            },
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    ),
    gap(14),
    Text(
      'Vorrat, Kochstatus und übrige Portionen werden lokal gespeichert. Sie werden erst beim Speichern verändert.',
      style: muted,
    ),
  ];

  void saveCookingResult() {
    if (cloudOffline) {
      offlineEditMessage();
      return;
    }
    if (cookingSession.cookedEntries.contains(cookingSession.key)) return;
    if (cookingSession.deductStock &&
        cookingSession.uses.any(
          (use) =>
              !pantry.contains(use.item) ||
              pantryAmount(use.item)?.$2.toLowerCase() !=
                  use.unit.toLowerCase() ||
              use.used > (pantryAmount(use.item)?.$1 ?? 0),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dein Vorrat hat sich geändert. Bitte prüfe die Verbrauchsmengen erneut.',
          ),
        ),
      );
      return;
    }
    update(() {
      if (cookingSession.deductStock) {
        for (final use in cookingSession.uses) {
          final remaining = pantryAmount(use.item)!.$1 - use.used;
          if (remaining <= 0) {
            pantry.remove(use.item);
          } else {
            use.item['amount'] = amountLabel(remaining, use.unit);
          }
        }
      }
      if (cookingSession.remainingCookedPortions > 0) {
        preparedMeals.add({
          'id': 'cooked-${DateTime.now().microsecondsSinceEpoch}',
          'name': cookingSession.recipe!.name,
          'portions': cookingSession.remainingCookedPortions,
          'location': cookingSession.cookedStorage,
          'storedOn': dateKey(pantryToday),
          'cookedOn': dateKey(cookingSession.cookedOn ?? pantryToday),
          'recipe': recipeSnapshot(cookingSession.recipe!),
        });
      }
      cookingHistory.add({
        'key': cookingSession.key,
        'date': dateKey(cookingSession.cookedOn ?? pantryToday),
        'recipeId': cookingSession.recipe!.id,
        'name': cookingSession.recipe!.name,
        'portions': cookingSession.portions,
        'savedLeftovers': cookingSession.remainingCookedPortions,
      });
      cookingSession.cookedEntries.add(cookingSession.key);
      cookingSession.page = 0;
    });
    cookingSession.ticker?.cancel();
    cookingSession.timers.clear();
    savePreferences();
    unawaited(persistCookingProgress(clear: true));
    unawaited(CookingRuntime.disableKeepScreenOn());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Als gekocht gespeichert · ${cookingSession.remainingCookedPortions} Portionen aufgehoben.',
        ),
      ),
    );
  }

  Widget cookingActionBar() {
    final alreadyCooked = cookingSession.cookedEntries.contains(
      cookingSession.key,
    );
    final label = cookingSession.page == 1
        ? 'Kochen starten'
        : cookingSession.page == 3
        ? 'Gekocht speichern'
        : cookingSession.step + 1 < cookingSession.recipe!.steps.length
        ? 'Weiter: Schritt ${cookingSession.step + 2}'
        : 'Zubereitung abschließen';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      alreadyCooked ||
                          (cloudOffline && cookingSession.page == 3) ||
                          (cookingSession.page == 1 &&
                              cookingSession.recipe!.steps.isEmpty)
                      ? null
                      : () {
                          if (cookingSession.page == 1) {
                            update(() {
                              cookingSession.step = 0;
                              cookingSession.page = 2;
                            });
                            unawaited(persistCookingProgress());
                          } else if (cookingSession.page == 3) {
                            saveCookingResult();
                          } else if (cookingSession.step + 1 <
                              cookingSession.recipe!.steps.length) {
                            update(() => cookingSession.step++);
                            unawaited(persistCookingProgress());
                          } else {
                            prepareCookingReview();
                          }
                        },
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  child: Text(
                    alreadyCooked
                        ? 'Bereits gekocht ✓'
                        : cloudOffline && cookingSession.page == 3
                        ? 'Zum Speichern verbinden'
                        : label,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (!alreadyCooked) ...[
                gap(4),
                TextButton(
                  onPressed: cancelCooking,
                  child: const Text('Kochvorgang abbrechen'),
                ),
              ],
              gap(8),
              Text(
                cookingSession.page == 3
                    ? 'Erst jetzt werden Vorräte und Reste aktualisiert.'
                    : 'Zutaten für ${cookingSession.portions} Portionen · Timer laufen beim Schrittwechsel weiter.',
                textAlign: TextAlign.center,
                style: muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
