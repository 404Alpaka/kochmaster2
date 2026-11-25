import 'package:supabase/supabase.dart';

/// These operations always address the authenticated account on the server.
/// No caller-supplied account or household ID is accepted.
class AccountDataManagementRepository {
  const AccountDataManagementRepository(this.client);

  final SupabaseClient client;

  Future<Map<String, dynamic>> exportData() async => Map<String, dynamic>.from(
    await client
            .rpc('export_my_account_data')
            .timeout(const Duration(seconds: 20))
        as Map,
  );

  Future<void> resetPersonalData(int revision) async {
    await client
        .rpc('reset_my_account_data', params: {'p_revision': revision})
        .timeout(const Duration(seconds: 30));
  }

  Future<void> deleteAccount() async {
    await client.rpc('delete_my_account').timeout(const Duration(seconds: 30));
  }
}
