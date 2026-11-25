import 'package:supabase/supabase.dart';

class AccountDocument {
  const AccountDocument(this.data, this.revision);
  final Map<String, dynamic> data;
  final int revision;
}

class AccountDataRepository {
  AccountDataRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  Future<AccountDocument?> load() async {
    final row = await client
        .from('user_preferences')
        .select('data,revision')
        .eq('user_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    return row == null
        ? null
        : AccountDocument(
            Map<String, dynamic>.from(row['data'] as Map),
            (row['revision'] as num).toInt(),
          );
  }

  Future<int> save(Map<String, dynamic> data, int revision) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Bitte erneut anmelden.');
    }
    final result = await client
        .rpc(
          'save_user_preferences',
          params: {'p_data': data, 'p_revision': revision, 'p_user': userId},
        )
        .timeout(const Duration(seconds: 20));
    return (result as num).toInt();
  }
}

const sharedAccountKeys = {
  'pantry',
  'pantryShoppingItems',
  'shoppingCategories',
  'shoppingPackageSizes',
  'shoppingTransfers',
  'householdDinerRules',
  'recipeCostEstimates',
  'budgetCostClass',
  'usePlanningStock',
  'preparedMeals',
  'planBudget',
  'planBudgetInitialized',
  'budget',
  'servings',
  'preferences',
  'survey',
  'weeklyExpenses',
  'weeklyReviews',
  'nextWeekHints',
  'cookingHistory',
  'cookedEntries',
};
Map<String, dynamic> sharedAccountData(Map<String, dynamic> data) => {
  for (final key in sharedAccountKeys)
    if (data.containsKey(key)) key: data[key],
};
Map<String, dynamic> privateAccountData(
  Map<String, dynamic> current,
  Map<String, dynamic> personal, {
  required bool householdActive,
}) => {
  for (final entry in current.entries)
    if (!householdActive || !sharedAccountKeys.contains(entry.key))
      entry.key: entry.value,
  if (householdActive) ...sharedAccountData(personal),
  if (householdActive) 'household': personal['household'],
};
