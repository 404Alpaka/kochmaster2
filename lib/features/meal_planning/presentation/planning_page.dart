import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

import '../../auth/data/session_storage.dart';

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import 'app_bottom_navigation.dart';
import 'food_preferences_page.dart';
import 'recipe_category_icon.dart';

import '../../recipes/data/admin_recipe_repository.dart';
import '../../recipes/data/supabase_recipe_repository.dart';
import '../../recipes/presentation/admin_recipes_page.dart';
import '../../recipes/presentation/recipe_editor_page.dart';

import 'package:supabase/supabase.dart';

import '../../auth/presentation/account_page.dart';
import '../data/weekly_plan_repository.dart';
import '../data/receipt_reader.dart';
import '../domain/receipt_parser.dart';
import '../domain/meal_plan.dart';
import '../domain/weekly_planner.dart';
import '../domain/planning_resources.dart';
import '../domain/planning_diner.dart';
import 'household_diners_page.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_image.dart';
import '../../account_data/data/account_data_repository.dart';
import '../../households/data/household_repository.dart';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../shopping/domain/build_shopping_list.dart';

part 'mise_views.dart';
part 'home_views.dart';
part 'week_action_card.dart';
part 'recipe_discovery_views.dart';
part 'account_sync.dart';
part 'connected_household_views.dart';
part 'planning_survey.dart';
part 'planning_budget_demo.dart';
part 'planning_proposal.dart';
part 'shopping_views.dart';
part 'pantry_views.dart';
part 'receipt_import_views.dart';
part 'household_views.dart';
part 'household_rules.dart';
part 'cooking_views.dart';
part 'prepared_meal_views.dart';
part 'recipe_collection_views.dart';
part 'weekly_review_views.dart';
part 'recipe_admin_actions.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({
    super.key,
    required this.recipes,
    required this.isDemo,
    this.client,
    this.user,
    this.store,
    this.adminRepository,
  });
  final SupabaseClient? client;
  final User? user;
  final WeeklyPlanRepository? store;
  final AdminRecipeRepository? adminRepository;
  final List<Recipe> recipes;
  final bool isDemo;
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  List<Recipe>? refreshedCatalog;
  bool admin = false;
  bool adminActionBusy = false;
  List<Recipe> get recipes => [
    ...(refreshedCatalog ?? widget.recipes),
    ...personalRecipes.map(
      (r) => recipeFromSnapshot(Map<String, dynamic>.from(r['recipe'] as Map)),
    ),
  ];
  List<Recipe> get dinnerRecipes => recipes.where(isDinnerRecipe).toList();
  final personalRecipes = <Map<String, dynamic>>[];
  int collectionPage = 0;
  String? recipeCategory;
  final collectionFilters = <String>{};
  String collectionQuery = '';
  Map<String, dynamic> personalRecipeDraft = {};
  String? personalRecipeError;
  String recipeImportText = '';
  String recipeImportSource = '';
  bool recipeImportLinkMode = false;
  bool importedPreview = false;
  final plan = <int, PlannedMeal>{};
  final checked = <(String, String)>{};
  static const days = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  int cookingPage = 0;
  Recipe? cookingRecipe;
  int cookingPortions = 2;
  int cookingStep = 0;
  int? cookingDay;
  DateTime? cookingDate;
  String cookingKey = '';
  Timer? cookingTicker;
  final cookingTimers = <int, _CookingTimer>{};
  final cookingUses = <_CookingUse>[];
  bool deductCookingStock = true;
  int remainingCookedPortions = 0;
  String cookedStorage = 'Kühlschrank';
  DateTime? cookedOn;
  final cookedEntries = <String>{};
  final preparedMeals = <Map<String, dynamic>>[];
  int tab = 5;
  int shoppingPage = 0;
  int selectedMarket = 0;
  bool shoppingExample = false;
  bool basketDelivery = false;
  final demoShoppingChecked = <String>{};
  bool showAllDemoProducts = false;
  bool includeOatDrink = true;
  String deliveryAddress = 'Zuhause · 10115 Berlin';
  String deliverySlot = 'Morgen · 18–20 Uhr';
  int servings = 2;
  int surveyStep = 0;
  bool surveyCompleted = false;
  final exclusions = <String>{};
  String diet = 'Ohne Einschränkung';
  int planningDays = 7;
  int maxMinutes = 30;
  int startDay = 0;
  Map<int, PlannedMeal>? draft;
  final acceptedDays = <int>{};
  PlannerResult? plannerResult;
  int plannerSeed = 0;
  bool allowPlanRepeats = false;
  final recipeRatings = <String, int>{};
  final recipeNotes = <String, String>{};
  final selfChosenRecipes = <String>{};
  final deferredRecipes = <String>{};
  final effortFeedback = <String, int>{};
  final dislikeFeedback = <String, int>{};
  final dayTimeLimits = <String, int>{};
  final householdDinerRules = <String, Map<String, dynamic>>{};
  final recipeCostEstimates = <String, double>{};
  String? budgetCostClass;
  bool usePlanningStock = true;
  String replacementReason = 'Diese Woche nicht';
  bool proposalConfirmed = false;
  bool editingPlan = false;
  int? swappingDay;
  Recipe? selectedReplacement;
  final changedProposalDays = <int>{};

  String query = '';
  int recipeFilter = 0;
  final recipeCategoryAnchor = GlobalKey();
  final rememberedRecipes = <String>{};
  final favoriteRecipes = <String>{};
  final hiddenRecipes = <String>{};
  int selectedDay = DateTime.now().weekday - 1;
  double budget = 75;
  double? planBudget;
  bool planBudgetInitialized = false;
  final budgetDemoSelections = <int>{0, 1, 2, 3};
  final weeklyReviews = <String, Map<String, dynamic>>{};
  final nextWeekHints = <String, Map<String, dynamic>>{};
  final cookingHistory = <Map<String, dynamic>>[];
  Map<String, dynamic> reviewDraft = {};
  final reviewSuggestions = <String>{};
  String? reviewError;
  String reviewReasonDraft = '';
  final weeklyExpenses = <String, double>{};
  double? get expenses => weeklyExpenses[dateKey(week)];
  set expenses(double? value) {
    if (value == null) {
      weeklyExpenses.remove(dateKey(week));
    } else {
      weeklyExpenses[dateKey(week)] = value;
    }
  }

  int householdPage = 0;
  bool householdDemoJoined = true;
  String demoAlexRole = 'Mitglied';
  String pendingMemberRole = 'Mitglied';
  bool roleConfirmed = false;
  bool leaveConfirmed = false;
  String invitationEmail = '';
  String invitationRole = 'Mitglied';
  String? invitationError;
  final householdInvitations = <Map<String, dynamic>>[];
  bool separateHouseholdMeals = true;
  Recipe? firstHouseholdRecipe;
  Recipe? secondHouseholdRecipe;
  int firstHouseholdPortions = 2;
  int secondHouseholdPortions = 1;
  int householdMealDay = 5;
  final personalExclusions = <String>{};
  final personalDislikes = <String>{};
  String? originalRule;
  String ruleName = '';
  bool personalRule = false;
  String dislikeName = '';
  String? originalDislike;
  bool dislikeActive = true;
  String? ruleError;
  String householdName = 'Zuhause';
  String preferences = 'Noch keine Vorlieben hinterlegt';
  String pantryFilter = 'Alle';
  final localWeekCache = <String, WeeklyPlan>{};
  bool preparedBusy = false;
  String? selectedPreparedId;
  Map<String, dynamic> preparedEditor = {};
  DateTime? preparedPlanDate;
  int preparedPlanPortions = 1;
  String? preparedError;
  int pantryPage = 0;
  List<Map<String, dynamic>> receiptDraft = [];
  bool receiptResolved = false;
  bool receiptIsDemo = true;
  String receiptSource = 'Beispiel-Bon';
  String? receiptFingerprint;
  final importedReceiptIds = <String>{};
  bool showAllReceiptItems = false;
  int leftoverRecipeIndex = 0;
  List<Map<String, dynamic>> pantry = [];
  final searchController = TextEditingController();

  bool get accountConnected => widget.client != null && widget.user != null;
  AccountDataRepository? accountRepository;
  HouseholdRepository? householdRepository;
  List<ConnectedHousehold> connectedHouseholds = [];
  String? activeHouseholdId;
  ConnectedHousehold? get activeHousehold {
    for (final household in connectedHouseholds) {
      if (household.id == activeHouseholdId) return household;
    }
    return null;
  }

  bool get readOnlyShared => activeHousehold?.role == 'viewer';
  HouseholdWeeklyPlanRepository? sharedWeekRepository;
  WeeklyPlanRepository? get weekRepository =>
      sharedWeekRepository ?? widget.store;
  Map<String, dynamic> personalCloudData = {};
  Map<String, dynamic> defaultAccountData = {};
  Map<String, dynamic> lastSharedData = {};
  int personalRevision = 0;
  int sharedRevision = 0;
  bool accountLoading = false;
  bool accountReady = false;
  String? accountError;
  int accountPending = 0;
  Future<void> accountSaveTail = Future.value();
  bool householdBusy = false;
  String? householdError;

  String get preferencesKey => 'mise-preferences-${widget.user?.id ?? 'guest'}';

  void update(VoidCallback change) => setState(change);

  Map<String, dynamic> preferencesData() => {
    'activeHouseholdId': activeHouseholdId,
    'rememberedRecipes': rememberedRecipes.toList(),
    'favoriteRecipes': favoriteRecipes.toList(),
    'hiddenRecipes': hiddenRecipes.toList(),
    'planBudget': planBudget,
    'planBudgetInitialized': planBudgetInitialized,
    'budget': budget,
    'weeklyExpenses': weeklyExpenses,
    'weeklyReviews': weeklyReviews,
    'nextWeekHints': nextWeekHints,
    'cookingHistory': cookingHistory,
    'recipeRatings': recipeRatings,
    'selfChosenRecipes': selfChosenRecipes.toList(),
    'effortFeedback': effortFeedback,
    'dislikeFeedback': dislikeFeedback,
    'dayTimeLimits': dayTimeLimits,
    'householdDinerRules': householdDinerRules,
    'recipeCostEstimates': recipeCostEstimates,
    'budgetCostClass': budgetCostClass,
    'usePlanningStock': usePlanningStock,
    'recipeNotes': recipeNotes,
    'plannerSeed': plannerSeed,
    'household': householdName,
    'householdDemoJoined': householdDemoJoined,
    'demoAlexRole': demoAlexRole,
    'householdInvitations': householdInvitations,
    'servings': servings,
    'preferences': preferences,
    'personalExclusions': personalExclusions.toList(),
    'personalDislikes': personalDislikes.toList(),
    'pantry': pantry,
    'importedReceiptIds': importedReceiptIds.toList(),
    'personalRecipes': personalRecipes,
    'cookedEntries': cookedEntries.toList(),
    'preparedMeals': preparedMeals,
    'survey': {
      'completed': surveyCompleted,
      'exclusions': exclusions.toList(),
      'diet': diet,
      'days': planningDays,
      'minutes': maxMinutes,
      'startDay': startDay,
    },
  };

  void savePreferences() {
    final data = preferencesData();
    if (!accountConnected) {
      writeSession(preferencesKey, jsonEncode(data));
      return;
    }
    if (!accountReady || accountLoading || accountError != null) return;
    queueAccountSave(data);
  }

  void restorePreferences() {
    try {
      final raw = readSession(preferencesKey);
      if (raw == null) return;
      applyPreferences(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      /* Invalid browser data stays local. */
    }
  }

  void applyPreferences(Map<String, dynamic> data) {
    rememberedRecipes.clear();
    selfChosenRecipes
      ..clear()
      ..addAll(List<String>.from(data['selfChosenRecipes'] as List? ?? []));
    for (final entry in {
      'effortFeedback': effortFeedback,
      'dislikeFeedback': dislikeFeedback,
      'dayTimeLimits': dayTimeLimits,
    }.entries) {
      entry.value
        ..clear()
        ..addAll(
          (data[entry.key] as Map? ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ),
        );
    }
    householdDinerRules
      ..clear()
      ..addAll(
        (data['householdDinerRules'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
        ),
      );
    recipeCostEstimates
      ..clear()
      ..addAll(
        (data['recipeCostEstimates'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );
    budgetCostClass = data['budgetCostClass'] as String?;
    usePlanningStock = data['usePlanningStock'] != false;
    deferredRecipes.clear();
    recipeRatings
      ..clear()
      ..addAll(
        (data['recipeRatings'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ),
      );
    recipeNotes
      ..clear()
      ..addAll(
        (data['recipeNotes'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, v as String),
        ),
      );
    plannerSeed = (data['plannerSeed'] as num?)?.toInt() ?? 0;
    favoriteRecipes.clear();
    hiddenRecipes.clear();
    weeklyReviews.clear();
    nextWeekHints.clear();
    cookingHistory.clear();
    weeklyExpenses.clear();
    householdInvitations.clear();
    personalExclusions.clear();
    personalDislikes.clear();
    exclusions.clear();
    cookedEntries.clear();
    preparedMeals.clear();
    personalRecipes.clear();

    rememberedRecipes.addAll(
      List<String>.from(data['rememberedRecipes'] as List? ?? []),
    );
    favoriteRecipes.addAll(
      List<String>.from(data['favoriteRecipes'] as List? ?? []),
    );
    hiddenRecipes.addAll(
      List<String>.from(data['hiddenRecipes'] as List? ?? []),
    );
    planBudget = (data['planBudget'] as num?)?.toDouble();
    planBudgetInitialized = data['planBudgetInitialized'] == true;
    budget = (data['budget'] as num?)?.toDouble() ?? 75;
    weeklyReviews.addAll(
      (data['weeklyReviews'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      ),
    );
    nextWeekHints.addAll(
      (data['nextWeekHints'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      ),
    );
    cookingHistory.addAll(
      (data['cookingHistory'] as List? ?? []).map(
        (v) => Map<String, dynamic>.from(v as Map),
      ),
    );
    final storedExpenses =
        data['weeklyExpenses'] as Map<String, dynamic>? ?? {};
    weeklyExpenses.addAll(
      storedExpenses.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
    householdDemoJoined = data['householdDemoJoined'] as bool? ?? true;
    demoAlexRole = data['demoAlexRole'] as String? ?? 'Mitglied';
    householdInvitations.addAll(
      (data['householdInvitations'] as List? ?? []).map(
        (v) => Map<String, dynamic>.from(v as Map),
      ),
    );
    householdName = data['household'] as String? ?? 'Zuhause';
    servings = data['servings'] as int? ?? 2;
    personalExclusions.addAll(
      List<String>.from(data['personalExclusions'] as List? ?? []),
    );
    personalDislikes.addAll(
      List<String>.from(data['personalDislikes'] as List? ?? []),
    );
    preferences = data['preferences'] as String? ?? preferences;
    final survey = data['survey'] as Map<String, dynamic>? ?? {};
    surveyCompleted = survey['completed'] == true;
    exclusions.addAll(List<String>.from(survey['exclusions'] as List? ?? []));
    diet = survey['diet'] as String? ?? diet;
    planningDays = (survey['days'] as int? ?? 7).clamp(1, 7);
    maxMinutes = survey['minutes'] as int? ?? 30;
    startDay = (survey['startDay'] as int? ?? 0).clamp(0, 6);
    cookedEntries.addAll(
      List<String>.from(data['cookedEntries'] as List? ?? []),
    );
    preparedMeals.addAll(
      (data['preparedMeals'] as List? ?? []).map(
        (p) => Map<String, dynamic>.from(p as Map),
      ),
    );
    personalRecipes.addAll(
      (data['personalRecipes'] as List? ?? []).map(
        (r) => Map<String, dynamic>.from(r as Map),
      ),
    );
    importedReceiptIds
      ..clear()
      ..addAll(List<String>.from(data['importedReceiptIds'] as List? ?? []));
    pantry = (data['pantry'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  void dispose() {
    cookingTicker?.cancel();
    searchController.dispose();
    super.dispose();
  }

  DateTime week = mondayOf(DateTime.now());
  bool loading = false;
  bool saving = false;
  String? loadError;
  String? saveError;
  bool weekConflict = false;
  bool weekSaveUncertain = false;
  bool saved = false;
  @override
  void initState() {
    super.initState();
    final invitation = Uri.base.queryParameters['household_invite'];
    if (invitation != null) {
      writeSession('mise-pending-household-invite', invitation);
    }
    defaultAccountData =
        jsonDecode(jsonEncode(preferencesData())) as Map<String, dynamic>;
    restorePreferences();
    personalCloudData = copyAccountData(preferencesData());
    if (accountConnected) {
      initializeAccountData();
    } else if (weekRepository != null) {
      loadWeek();
    }
    if (widget.adminRepository != null) {
      admin = true;
    } else if (widget.user != null) {
      checkAdmin();
    }
  }

  Future<void> checkAdmin() async {
    try {
      final allowed = await widget.client!
          .rpc('is_recipe_admin')
          .timeout(const Duration(seconds: 15));
      if (mounted) setState(() => admin = allowed == true);
    } catch (_) {
      if (mounted) setState(() => admin = false);
    }
  }

  Future<void> manageRecipes() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminRecipesPage(
          repository: SupabaseAdminRecipeRepository(widget.client!),
        ),
      ),
    );
    if (!mounted) return;
    try {
      final updated = await SupabaseRecipeRepository(widget.client!).getAll();
      if (mounted) setState(() => refreshedCatalog = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Katalog konnte nicht aktualisiert werden. Bitte lade die Seite neu.',
            ),
          ),
        );
      }
    }
  }

  String displayDate(DateTime date) => '${date.day}.${date.month}.${date.year}';
  Future<void> loadWeek() async {
    setState(() {
      loading = true;
      loadError = null;
      saveError = null;
    });
    try {
      final result = await weekRepository!.load(week, recipes);
      if (!mounted) return;
      setState(() {
        saved = true;
        plan
          ..clear()
          ..addAll(result.meals);
        checked
          ..clear()
          ..addAll(result.checked);
        weekConflict = false;
        weekSaveUncertain = false;
        draft = null;
        proposalConfirmed = false;
        swappingDay = null;
      });
    } catch (error) {
      if (mounted) {
        final missingRevision =
            error is PostgrestException &&
            error.code == '42703' &&
            error.message.contains('revision');
        setState(
          () => loadError = missingRevision
              ? 'Für das Laden und Speichern fehlt die Datenbankmigration 202611180001_private_week_plan_revisions.sql. Bitte im Supabase SQL Editor ausführen und den Wochenplan erneut laden.'
              : 'Dein Wochenplan konnte nicht geladen werden. Prüfe die Verbindung. Möglicherweise ist ein geplantes Rezept nicht mehr verfügbar.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> account() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountPage(client: widget.client!),
      ),
    );
  }

  Future<void> signOut() async {
    try {
      await widget.client!.auth.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abmeldung fehlgeschlagen. Bitte erneut versuchen.'),
          ),
        );
      }
    }
  }

  Future<bool> persist(
    Map<int, PlannedMeal> nextPlan,
    Set<(String, String)> nextChecked,
  ) async {
    if (weekConflict ||
        readOnlyShared ||
        (accountConnected && (!accountReady || accountError != null)) ||
        saving ||
        loading ||
        loadError != null) {
      return false;
    }
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await weekRepository?.save(
        week,
        WeeklyPlan(meals: nextPlan, checked: nextChecked),
      );
      if (!mounted) return false;
      setState(() {
        saved = true;
        plan
          ..clear()
          ..addAll(nextPlan);
        checked
          ..clear()
          ..addAll(nextChecked);
      });
      syncPreparedReservations(week, nextPlan);
      savePreferences();
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          weekSaveUncertain = error is TimeoutException;
          weekConflict =
              weekSaveUncertain ||
              (error is PostgrestException && error.code == '40001');
          saveError = weekSaveUncertain
              ? 'Die Datenbank hat nicht rechtzeitig geantwortet. Ob die Änderung gespeichert wurde, ist noch unklar. Lade den Wochenplan erneut, bevor du weitere Änderungen speicherst.'
              : weekConflict
              ? 'Dieser Wochenplan wurde auf einem anderen Gerät oder in einem anderen Tab geändert. Deine Änderung wurde nicht gespeichert. Lade den aktuellen Wochenplan über den Aktualisieren-Knopf und führe deine Änderung danach erneut aus.'
              : 'Die Änderung wurde nicht gespeichert. Dein letzter gespeicherter Stand bleibt erhalten. Bitte versuche die Änderung erneut.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              weekSaveUncertain
                  ? 'Speicherstand unklar. Bitte den Wochenplan neu laden.'
                  : weekConflict
                  ? 'Wochenplan wurde zwischenzeitlich geändert. Bitte den aktuellen Stand neu laden.'
                  : 'Nicht gespeichert. Bitte prüfe deine Verbindung und versuche es erneut.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> changeWeek(int delta) async {
    if (saving || loading || delta == 0) return;
    if (draft != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Woche wechseln?'),
          content: const Text(
            'Dein unbestätigter Vorschlag wird verworfen. Bereits gespeicherte Wochenpläne bleiben erhalten.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hier bleiben'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Woche wechseln'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted || saving || loading) return;
    }
    final previousSurveyStep = surveyStep;
    localWeekCache[dateKey(week)] = WeeklyPlan(
      meals: Map<int, PlannedMeal>.from(plan),
      checked: Set<(String, String)>.from(checked),
    );
    setState(() {
      week = DateTime(week.year, week.month, week.day + delta * 7);
      selectedDay = dateKey(week) == dateKey(mondayOf(pantryToday))
          ? pantryToday.weekday - 1
          : 0;
      draft = null;
      editingPlan = false;
      allowPlanRepeats = false;
      deferredRecipes.clear();
      plannerResult = null;
      swappingDay = null;
      selectedReplacement = null;
      acceptedDays.clear();
      changedProposalDays.clear();
      proposalConfirmed = false;
      surveyStep = 0;
      plan.clear();
      checked.clear();
    });
    if (weekRepository != null) {
      await loadWeek();
    } else {
      final cached = localWeekCache[dateKey(week)];
      if (cached != null) {
        update(() {
          plan.addAll(cached.meals);
          checked.addAll(cached.checked);
        });
      }
    }
    if (mounted &&
        previousSurveyStep > 0 &&
        previousSurveyStep <= 5 &&
        loadError == null) {
      update(() => surveyStep = previousSurveyStep);
    }
  }

  Future<void> addRecipe(Recipe recipe, {int? portions}) async {
    if (readOnlyShared) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dieser Haushalt ist für dich nur lesbar.'),
        ),
      );
      return;
    }
    if (widget.client != null && widget.user == null) {
      await account();
      return;
    }
    if (saving || loading || loadError != null) return;
    final day = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tag auswählen'),
        children: [
          for (var i = 0; i < days.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text(
                '${days[i]}${plan.containsKey(i) ? ' · Gericht ersetzen' : ''}',
              ),
            ),
        ],
      ),
    );
    if (day == null || !mounted) return;
    if (!matchesVerifiedRestrictions(recipe, diet, {
          ...exclusions,
          ...personalExclusions,
        }) ||
        planningDiners
            .where((d) => d.participates)
            .any((d) => !d.allows(recipe))) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konflikt mit deinen festen Regeln'),
          content: const Text(
            'Dieses Rezept enthält ausgeschlossene Allergene, passt nicht zur Ernährungsweise oder hat keine verlässlich geprüften Angaben. Bitte prüfe die Zutaten und Produktkennzeichnung.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bewusst selbst einplanen'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    final next = Map<int, PlannedMeal>.from(plan)
      ..[day] = PlannedMeal(recipe, portions ?? servings);
    if (!await saveMeals(next)) return;
    selfChosenRecipes.add(recipe.id);
    savePreferences();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${recipe.name} für ${days[day]} geplant')),
    );
  }

  Future<bool> saveMeals(Map<int, PlannedMeal> next) =>
      persist(next, retainCheckedItems(plan.values, next.values, checked));

  Future<void> adjustServings(int day, int delta) async {
    final meal = plan[day];
    if (meal == null || meal.servings + delta < 1 || meal.preparedConsumed) {
      return;
    }
    if (meal.preparedMealId != null) {
      final stored = findPreparedMeal(meal.preparedMealId!);
      if (stored == null ||
          meal.servings + delta >
              preparedAvailable(
                stored,
                exceptDate: dateKey(week.add(Duration(days: day))),
              )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nicht genug freie Portionen vorhanden.'),
          ),
        );
        return;
      }
    }
    final next = Map<int, PlannedMeal>.from(plan)
      ..[day] = PlannedMeal(
        meal.recipe,
        meal.servings + delta,
        preparedMealId: meal.preparedMealId,
      );
    await saveMeals(next);
  }

  Recipe? openedRecipe;
  int detailServings = 2;

  void details(Recipe recipe) => update(() {
    tab = 0;
    openedRecipe = recipe;
    detailServings = recipe.servings;
  });

  @override
  Widget build(BuildContext context) =>
      accountConnected ? accountDataScaffold() : miseScaffold();
}
