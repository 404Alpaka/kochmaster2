import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/core/local_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() async {
    // Widget tests have no native preferences plugin. Give each test an isolated
    // store so app startup exercises normal restoration, not a platform error.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    LocalStore.instance = LocalStore();
    await LocalStore.instance.initialize();
  });
  await testMain();
}
