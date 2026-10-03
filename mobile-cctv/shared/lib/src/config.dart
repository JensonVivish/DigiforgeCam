const String _envDbUrl = String.fromEnvironment('DB_URL');
const String _placeholderDbUrl = 'https://digiforge-cctv-b9fee-default-rtdb.firebaseio.com';

/// Your Firebase Realtime Database URL.
/// Paste it below (replace the placeholder) or build with --dart-define=DB_URL=...
const String kDatabaseUrl = _envDbUrl == '' ? _placeholderDbUrl : _envDbUrl;

bool get dbConfigured => !kDatabaseUrl.contains('YOUR-PROJECT');

/// How often the camera writes its presence heartbeat.
const Duration kPresenceBeat = Duration(seconds: 5);
