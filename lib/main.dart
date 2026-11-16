import 'package:material_ui/material_ui.dart';

import 'features/auth/data/create_auth_client.dart';

import 'app/kochmaster_app.dart';
import 'core/config/app_config.dart';
import 'features/recipes/data/supabase_recipe_repository.dart';

void main() {
  const url = AppConfig.url;
  const key = AppConfig.publishableKey;
  if (AppConfig.useDemo) {
    runApp(const KochmasterApp());
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      key.isEmpty ||
      key.startsWith('sb_secret_')) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Bitte SUPABASE_URL und den öffentlichen SUPABASE_PUBLISHABLE_KEY prüfen.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  final client = createAuthClient(url, key);
  runApp(
    KochmasterApp(repository: SupabaseRecipeRepository(client), client: client),
  );
}
