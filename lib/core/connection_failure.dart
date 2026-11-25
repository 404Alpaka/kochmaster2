import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase/supabase.dart';

bool isConnectionFailure(Object error) =>
    error is TimeoutException ||
    error is ClientException ||
    error is AuthRetryableFetchException ||
    (error is PostgrestException &&
        [
          '502',
          '503',
          '504',
          'PGRST000',
          'PGRST001',
          'PGRST002',
          '08006',
        ].contains(error.code));
