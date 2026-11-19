const _callbackFields = {'code', 'error', 'error_code', 'error_description'};

Map<String, String> _fragmentParameters(Uri uri) {
  try {
    return Uri.splitQueryString(uri.fragment);
  } on FormatException {
    return {};
  }
}

/// Do not display the server's raw error_description or tokens in the UI.
String? authErrorFromUri(Uri uri) {
  final values = {..._fragmentParameters(uri), ...uri.queryParameters};
  if (values.containsKey('error') || values.containsKey('error_code')) {
    return values['error_code'] ?? 'invalid_email_link';
  }
  return null;
}

String authReturnAddress(Uri uri) =>
    uri.toString().split(RegExp(r'[?#]')).first;

Uri withoutAuthCallback(Uri uri) {
  final query = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((key, _) => _callbackFields.contains(key));
  final fragment = _fragmentParameters(uri);
  final hasErrorFragment =
      fragment.containsKey('error') || fragment.containsKey('error_code');
  if (hasErrorFragment) {
    fragment.removeWhere((key, _) => _callbackFields.contains(key));
  }
  final cleanFragment = hasErrorFragment
      ? Uri(queryParameters: fragment.isEmpty ? null : fragment).query
      : uri.fragment;
  return Uri.parse(authReturnAddress(uri)).replace(
    queryParameters: query.isEmpty ? null : query,
    fragment: cleanFragment.isEmpty ? null : cleanFragment,
  );
}
