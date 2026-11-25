part of 'planning_page.dart';

extension _WeeklyReviewViews on _PlanningPageState {
  Map<String, dynamic> get currentReview => weeklyReviews[dateKey(week)] ?? {};
  List<Map<String, dynamic>> reviewRows(
    Map<String, dynamic> record,
    String key,
  ) => ((record[key] as List?) ?? [])
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();
  Map<String, dynamic> get reviewStatuses =>
      Map<String, dynamic>.from(currentReview['statuses'] as Map? ?? {});
  List<int> get reviewedCookingDays =>
      plan.entries
          .where((e) => e.value.preparedMealId == null)
          .map((e) => e.key)
          .toList()
        ..sort();
  String actualCookingStatus(int day) {
    final value = reviewStatuses['$day'];
    if (value is String) return value;
    final meal = plan[day];
    return meal != null &&
            cookingSession.cookedEntries.contains(
              '${dateKey(week.add(Duration(days: day)))}:${meal.recipe.id}',
            )
        ? 'cooked'
        : 'unknown';
  }

  int get actualCookingCount => reviewedCookingDays
      .where((d) => actualCookingStatus(d) == 'cooked')
      .length;
  int get knownCookingCount => reviewedCookingDays
      .where((d) => actualCookingStatus(d) != 'unknown')
      .length;
  int get suggestedCookingDays => actualCookingCount.clamp(1, 7).toInt();
  bool get canSuggestFewerDays =>
      reviewedCookingDays.isNotEmpty &&
      knownCookingCount == reviewedCookingDays.length &&
      actualCookingCount > 0 &&
      actualCookingCount < reviewedCookingDays.length;
  double? reviewNumber(dynamic value) =>
      double.tryParse((value?.toString() ?? '').replaceAll(',', '.'));
  double reviewExpenseSum(Map<String, dynamic> record) => reviewRows(
    record,
    'expenses',
  ).fold<double>(0, (sum, r) => sum + (reviewNumber(r['amount']) ?? 0));
  bool reviewExpensesComplete(Map<String, dynamic> record) =>
      record['expensesComplete'] == true &&
      reviewRows(record, 'expenses').isNotEmpty &&
      reviewRows(
        record,
        'expenses',
      ).every((r) => reviewNumber(r['amount']) != null);
  String wasteSummary(Map<String, dynamic> record) {
    final rows = reviewRows(record, 'waste');
    if (rows.isEmpty)
      return record['noWaste'] == true
          ? 'Ausdrücklich kein Abfall gemeldet'
          : 'Nicht erfasst';
    final totals = <String, double>{};
    for (final r in rows) {
      final unit = r['unit'] as String;
      totals[unit] = (totals[unit] ?? 0) + (reviewNumber(r['quantity']) ?? 0);
    }
    return totals.entries.map((e) => amountLabel(e.value, e.key)).join(' · ');
  }

  List<Map<String, dynamic>> get weekCookingHistory =>
      cookingHistory.where((entry) {
        final date = DateTime.tryParse(entry['date'] as String? ?? '');
        return date != null &&
            !date.isBefore(week) &&
            date.isBefore(week.add(const Duration(days: 7)));
      }).toList();
  Widget reviewPair(
    String firstLabel,
    String firstValue,
    String firstNote,
    String secondLabel,
    String secondValue,
    String secondNote, {
    bool incomplete = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(firstLabel, style: muted),
              gap(5),
              Text(
                firstValue,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              gap(5),
              Text(firstNote, style: muted.copyWith(fontSize: 12)),
            ],
          ),
          color: AppColors.softGreen,
          padding: const EdgeInsets.all(12),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(secondLabel, style: muted),
              gap(5),
              Text(
                secondValue,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              gap(5),
              Text(secondNote, style: muted.copyWith(fontSize: 12)),
            ],
          ),
          color: incomplete ? const Color(0xFFF6E9CF) : AppColors.softGreen,
          padding: const EdgeInsets.all(12),
        ),
      ),
    ],
  );

  List<Widget> weeklyReviewView() {
    final rows = reviewRows(currentReview, 'expenses');
    final complete = reviewExpensesComplete(currentReview);
    final estimate = reviewNumber(currentReview['estimate']);
    final leftovers = weekCookingHistory.fold<int>(
      0,
      (sum, h) => sum + (h['savedLeftovers'] as num).toInt(),
    );
    return [
      gap(14),
      title('Was war wirklich?'),
      gap(12),
      Text(
        '${displayDate(week)} – ${displayDate(week.add(const Duration(days: 6)))}\nNur geplante Abendessen und zugehörige Einkäufe.',
        style: muted,
      ),
      gap(14),
      weekPicker(),
      gap(18),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section('Abendessen selbst gekocht'),
            reviewPair(
              'Geplant',
              '${reviewedCookingDays.length}',
              'Kochtermine',
              'Ist',
              '$actualCookingCount',
              'als gekocht erfasst',
            ),
            gap(10),
            Text(
              '$knownCookingCount von ${reviewedCookingDays.length} Terminen gepflegt. Nicht erfasste Termine sind unbekannt; geplante Reste zählen nicht als neues Kochen.',
              style: muted,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
      ),
      gap(18),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section('Einkauf für die Abendessen'),
            reviewPair(
              'Plan',
              estimate == null ? '—' : euro(estimate),
              estimate == null
                  ? 'keine Kostenschätzung'
                  : 'eigene Kostenschätzung',
              'Erfasst',
              rows.any((r) => reviewNumber(r['amount']) != null)
                  ? euro(reviewExpenseSum(currentReview))
                  : '—',
              complete ? 'als vollständig bestätigt' : 'noch unvollständig',
              incomplete: !complete,
            ),
            gap(10),
            Text(
              '${rows.where((r) => reviewNumber(r['amount']) != null).length} von ${rows.length} Einkaufsbeträgen erfasst. ${complete && estimate != null ? '${euro((reviewExpenseSum(currentReview) - estimate).abs())} ${reviewExpenseSum(currentReview) > estimate ? 'mehr' : 'weniger'} als deine Schätzung.' : 'Noch keine verlässliche Differenz oder Ersparnis ausweisen.'}',
              style: muted,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
      ),
      gap(18),
      surveyCard(
        'Weggeworfen: ${wasteSummary(currentReview)}',
        'Keine Abfallprognose. Mengen stammen nur aus deinen Einträgen. Nicht erfasst bedeutet nicht „0“. Verschiedene Einheiten werden nicht zusammengerechnet.',
        color: AppColors.cream,
      ),
      gap(18),
      surveyCard(
        weekCookingHistory.isEmpty
            ? 'Restespeicherung: nicht protokolliert'
            : '$leftovers Portionen als Reste gespeichert',
        'Ein Vorgang im Wochenverlauf, kein aktueller Lagerbestand. Frühere Kochvorgänge ohne Protokoll werden nicht geschätzt.',
        color: AppColors.softGreen,
      ),
      gap(18),
      recipeAction(
        'Nächste Woche passender planen →',
        false,
        openReviewSuggestions,
      ),
    ];
  }

  void editWeeklyReview() => update(() {
    reviewDraft = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(currentReview)) as Map,
    );
    reviewDraft['expenses'] ??= <Map<String, dynamic>>[];
    reviewDraft['waste'] ??= <Map<String, dynamic>>[];
    reviewDraft['statuses'] = {
      for (final day in reviewedCookingDays) '$day': actualCookingStatus(day),
    };
    reviewError = null;
    householdPage = 12;
  });
  List<Map<String, dynamic>> get expenseDraftRows =>
      (reviewDraft['expenses'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get wasteDraftRows =>
      (reviewDraft['waste'] as List).cast<Map<String, dynamic>>();
  void addReviewExpense() => update(
    () => expenseDraftRows.add({
      'key': '${DateTime.now().microsecondsSinceEpoch}',
      'amount': '',
      'date': dateKey(week),
    }),
  );
  void addReviewWaste() => update(() {
    reviewDraft['noWaste'] = false;
    wasteDraftRows.add({
      'key': '${DateTime.now().microsecondsSinceEpoch}',
      'name': '',
      'quantity': '',
      'unit': 'g',
      'reason': '',
      'date': dateKey(week),
    });
  });
  Widget reviewDateField(
    Map<String, dynamic> row,
    String label,
  ) => TextButton.icon(
    icon: const Icon(Icons.event_outlined, size: 18),
    label: Text('$label: ${preparedDateLabel(row['date'])}'),
    onPressed: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(row['date'] as String? ?? '') ?? week,
        firstDate: week,
        lastDate: week.add(const Duration(days: 6)),
      );
      if (date != null && mounted) update(() => row['date'] = dateKey(date));
    },
  );
  List<Widget> weeklyReviewEditor() => [
    gap(14),
    title('Die Woche vervollständigen.'),
    gap(12),
    Text(
      'Deine Einträge für ${displayDate(week)} · noch nicht gespeichert.',
      style: muted,
    ),
    gap(18),
    section('Kochtermine ergänzen'),
    for (final day in reviewedCookingDays) ...[
      DropdownButtonFormField<String>(
        initialValue: (reviewDraft['statuses'] as Map)['$day'] as String,
        decoration: InputDecoration(
          labelText:
              '${_PlanningPageState.days[day]} · ${plan[day]!.recipe.name}',
        ),
        items: const [
          DropdownMenuItem(value: 'unknown', child: Text('Nicht erfasst')),
          DropdownMenuItem(value: 'cooked', child: Text('Gekocht')),
          DropdownMenuItem(value: 'notCooked', child: Text('Nicht gekocht')),
        ],
        onChanged: (v) => (reviewDraft['statuses'] as Map)['$day'] = v,
      ),
      gap(14),
    ],
    section('Einkäufe für geplante Abendessen'),
    surveyCard(
      'Vergleich nur im gleichen Umfang.',
      'Frühstück, Snacks und Zusatzartikel nicht als Abendessenkosten einrechnen. Erfasste Gebühren gehören zum jeweiligen Einkauf.',
      color: AppColors.cream,
    ),
    gap(14),
    for (final row in expenseDraftRows) ...[
      TextFormField(
        key: ValueKey('expense-${row['key']}'),
        initialValue: row['amount'] as String? ?? '',
        decoration: const InputDecoration(
          labelText: 'Tatsächlich gezahlter Betrag · leer = fehlt',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => row['amount'] = v,
      ),
      Row(
        children: [
          Expanded(child: reviewDateField(row, 'Einkauf')),
          IconButton(
            tooltip: 'Einkauf entfernen',
            onPressed: () => update(() => expenseDraftRows.remove(row)),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      gap(14),
    ],
    recipeAction('Einkaufsbetrag hinzufügen +', false, addReviewExpense),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Alle zugehörigen Einkaufsbeträge sind vollständig.'),
      value: reviewDraft['expensesComplete'] == true,
      onChanged: (v) => update(() => reviewDraft['expensesComplete'] = v),
    ),
    gap(14),
    TextFormField(
      initialValue: reviewDraft['estimate'] as String? ?? '',
      decoration: const InputDecoration(
        labelText: 'Eigene Kostenschätzung zum Plan · optional',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => reviewDraft['estimate'] = v,
    ),
    gap(18),
    section('Weggeworfen ergänzen'),
    for (final row in wasteDraftRows) ...[
      TextFormField(
        key: ValueKey('waste-${row['key']}'),
        initialValue: row['name'] as String,
        decoration: const InputDecoration(labelText: 'Lebensmittel'),
        onChanged: (v) => row['name'] = v,
      ),
      gap(10),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              key: ValueKey('waste-quantity-${row['key']}'),
              initialValue: row['quantity'] as String,
              decoration: const InputDecoration(labelText: 'Menge'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) => row['quantity'] = v,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              key: ValueKey('waste-unit-${row['key']}'),
              initialValue: row['unit'] as String,
              decoration: const InputDecoration(labelText: 'Einheit'),
              onChanged: (v) => row['unit'] = v,
            ),
          ),
        ],
      ),
      gap(10),
      TextFormField(
        key: ValueKey('waste-reason-${row['key']}'),
        initialValue: row['reason'] as String,
        decoration: const InputDecoration(labelText: 'Grund · optional'),
        onChanged: (v) => row['reason'] = v,
      ),
      Row(
        children: [
          Expanded(child: reviewDateField(row, 'Tag')),
          IconButton(
            tooltip: 'Abfalleintrag entfernen',
            onPressed: () => update(() => wasteDraftRows.remove(row)),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      gap(18),
    ],
    recipeAction('Abfalleintrag hinzufügen +', false, addReviewWaste),
    if (wasteDraftRows.isEmpty)
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ausdrücklich keinen Abfall gemeldet'),
        value: reviewDraft['noWaste'] == true,
        onChanged: (v) => update(() => reviewDraft['noWaste'] = v),
      ),
    gap(18),
    surveyCard(
      'Nur deine Rückblick-Einträge übernehmen.',
      'Nicht protokollierte Mengen bleiben unbekannt. „Nicht gekocht“ wird nicht als Abfall gewertet. Diese Angaben ändern keine Vorräte, Kochprotokolle oder Mahlzeitenbestände.',
      color: AppColors.softGreen,
    ),
    if (reviewError != null) ...[
      gap(14),
      Text(
        reviewError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
  ];

  void saveWeeklyReview() {
    bool validNonnegative(dynamic value) {
      final n = reviewNumber(value);
      return n != null && n.isFinite && n >= 0;
    }

    final expensesValid = expenseDraftRows.every(
      (r) =>
          (r['amount'] as String).trim().isEmpty ||
          validNonnegative(r['amount']),
    );
    final completeValid =
        reviewDraft['expensesComplete'] != true ||
        (expenseDraftRows.isNotEmpty &&
            expenseDraftRows.every((r) => validNonnegative(r['amount'])));
    final estimate = (reviewDraft['estimate'] as String? ?? '').trim();
    final wasteValid = wasteDraftRows.every(
      (r) =>
          (r['name'] as String).trim().isNotEmpty &&
          (r['unit'] as String).trim().isNotEmpty &&
          validNonnegative(r['quantity']) &&
          reviewNumber(r['quantity'])! > 0,
    );
    if (!expensesValid ||
        !completeValid ||
        !wasteValid ||
        (estimate.isNotEmpty && !validNonnegative(estimate))) {
      update(
        () => reviewError = 'Bitte gültige Beträge und positive Abfallmengen mit Namen und Einheit eintragen. Vollständige Einkäufe dürfen keine fehlenden Beträge enthalten.',
      );
      return;
    }
    for (final day in reviewedCookingDays) {
      final key =
          'review:${dateKey(week.add(Duration(days: day)))}:${plan[day]!.recipe.id}';
      final status = (reviewDraft['statuses'] as Map)['$day'];
      cookingHistory.removeWhere((h) => h['key'] == key);
      if (status == 'cooked')
        cookingHistory.add({
          'key': key,
          'date': dateKey(week.add(Duration(days: day))),
          'recipeId': plan[day]!.recipe.id,
          'name': plan[day]!.recipe.name,
          'portions': plan[day]!.servings,
          'savedLeftovers': 0,
          'source': 'review',
        });
    }
    update(() {
      weeklyReviews[dateKey(week)] = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(reviewDraft)) as Map,
      );
      householdPage = 11;
    });
    savePreferences();
  }

  void openReviewSuggestions() => update(() {
    reviewSuggestions.clear();
    reviewReasonDraft = currentReview['reason'] as String? ?? '';
    if (canSuggestFewerDays) reviewSuggestions.add('days');
    if (reviewRows(currentReview, 'waste').isNotEmpty)
      reviewSuggestions.add('waste');
    if (preparedMeals.any((m) => preparedAvailable(m) > 0))
      reviewSuggestions.add('leftovers');
    householdPage = 13;
  });
  Widget reviewSuggestion(String key, String heading, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: surveyChoice(
      heading,
      reviewSuggestions.contains(key),
      () => update(() {
        if (!reviewSuggestions.add(key)) reviewSuggestions.remove(key);
      }),
      subtitle: body,
    ),
  );
  List<Widget> weeklyReviewNextView() {
    final waste = reviewRows(currentReview, 'waste');
    final complete = reviewExpensesComplete(currentReview);
    final estimate = reviewNumber(currentReview['estimate']);
    return [
      gap(14),
      title('Nächste Woche passender.'),
      gap(12),
      Text(
        'Wünsche für ${displayDate(week.add(const Duration(days: 7)))} – ${displayDate(week.add(const Duration(days: 13)))}',
        style: muted,
      ),
      gap(18),
      surveyCard(
        'Plan und Ist nach der Ergänzung',
        'Gekocht: $actualCookingCount von ${reviewedCookingDays.length} geplanten Kochterminen. $knownCookingCount Termine gepflegt.\nAusgaben: ${reviewRows(currentReview, 'expenses').isEmpty ? 'nicht erfasst' : euro(reviewExpenseSum(currentReview))} · ${complete ? 'vollständig bestätigt' : 'unvollständig'}.\n${complete && estimate != null ? 'Differenz zur eigenen Schätzung: ${euro((reviewExpenseSum(currentReview) - estimate).abs())} ${reviewExpenseSum(currentReview) > estimate ? 'mehr' : 'weniger'}.\n' : ''}Weggeworfen: ${wasteSummary(currentReview)}.',
      ),
      gap(18),
      if (canSuggestFewerDays)
        reviewSuggestion(
          'days',
          '$suggestedCookingDays statt ${reviewedCookingDays.length} Abendessen planen',
          'Nicht genutzte Kochtermine bewusst freihalten. Die Auswahl passt nur die Anzahl für den nächsten Vorschlag an.',
        ),
      if (waste.isNotEmpty)
        reviewSuggestion(
          'waste',
          'Gemeldete Lebensmittel gezielter einkaufen',
          '${waste.map((r) => r['name']).toSet().join(', ')}: als Einkaufshinweis für die nächste Woche übernehmen. Packungsgrößen und Preise werden noch nicht automatisch optimiert.',
        ),
      if (preparedMeals.any((m) => preparedAvailable(m) > 0))
        reviewSuggestion(
          'leftovers',
          'Vorhandene Mahlzeiten zuerst prüfen',
          'Nur aktuell verfügbare, nicht reservierte Portionen ansehen. Keine automatische Einplanung oder Bestandsänderung.',
        ),
      if (!canSuggestFewerDays &&
          waste.isEmpty &&
          !preparedMeals.any((m) => preparedAvailable(m) > 0)) ...[
        surveyCard(
          'Noch keine belastbaren Anpassungen',
          'Ergänze fehlende Ist-Werte. Du kannst die nächste Woche auch mit deinen bisherigen Angaben planen.',
          color: AppColors.softGreen,
        ),
        gap(18),
      ],
      TextFormField(
        initialValue: reviewReasonDraft,
        decoration: const InputDecoration(
          labelText: 'Warum fiel ein Kochtermin aus? · optional',
        ),
        maxLines: 3,
        onChanged: (v) => reviewReasonDraft = v,
      ),
      gap(18),
      surveyCard(
        'Du bestätigst die Änderungen.',
        'Dein Planbudget und feste Ausschlüsse bleiben erhalten. Nur ausgewählte Wünsche werden übernommen. Produktpreise und Packungsgrößen sind noch nicht angebunden.',
        color: AppColors.cream,
      ),
    ];
  }

  Future<void> applyReviewSuggestions() async {
    if (saving || loading) return;
    final target = week.add(const Duration(days: 7));
    final fewerDays = canSuggestFewerDays && reviewSuggestions.contains('days')
        ? suggestedCookingDays
        : null;
    final note = [
      if (fewerDays != null) '$fewerDays Abendessen gewünscht.',
      if (reviewSuggestions.contains('waste'))
        'Gezielter einkaufen: ${reviewRows(currentReview, 'waste').map((r) => r['name']).toSet().join(', ')}.',
      if (reviewSuggestions.contains('leftovers'))
        'Vorhandene Mahlzeiten vor der Planung prüfen.',
    ].join('\n');
    weeklyReviews.putIfAbsent(dateKey(week), () => {})['reason'] =
        reviewReasonDraft;
    nextWeekHints[dateKey(target)] = {
      'note': note.isEmpty ? 'Bisherige Planungsangaben beibehalten.' : note,
      'checkPrepared': reviewSuggestions.contains('leftovers'),
    };
    savePreferences();
    await changeWeek(1);
    if (!mounted || loadError != null) return;
    update(() {
      if (fewerDays != null) {
        planningDays = fewerDays;
        startDay = 0;
      }
      tab = 1;
      householdPage = 0;
      surveyStep = 3;
      draft = null;
      proposalConfirmed = false;
    });
    savePreferences();
  }

  Widget weeklyReviewActionBar() {
    final label = householdPage == 11
        ? 'Ist-Werte ergänzen'
        : householdPage == 12
        ? 'Einträge für den Rückblick speichern'
        : 'Mit diesen Wünschen weiterplanen';
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
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  onPressed: saving || loading
                      ? null
                      : () {
                          if (householdPage == 11) {
                            editWeeklyReview();
                          } else if (householdPage == 12) {
                            saveWeeklyReview();
                          } else {
                            applyReviewSuggestions();
                          }
                        },
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
              gap(8),
              Text(
                householdPage == 13
                    ? 'Nur ausgewählte Wünsche für die nächste Woche verwenden.'
                    : 'Planwerte und tatsächliche Einträge bleiben getrennt.',
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
