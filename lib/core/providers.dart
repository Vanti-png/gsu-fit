import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/database/app_database.dart';
import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/media/media_cache.dart';
import 'package:gsu_fit/core/platform/native_bridge.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';

/// Android: opened in main() before the first frame and injected via
/// overrides. Never read on the web.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider is overridden in main()'),
);

/// Web: the browser-backed store that replaces SQLite. Never read on Android.
final jsonStoreProvider = Provider<JsonStore>(
  (ref) => throw UnimplementedError('jsonStoreProvider is overridden in main()'),
);

final mediaCacheProvider = Provider<MediaCache>(
  (ref) => throw UnimplementedError('mediaCacheProvider is overridden in main()'),
);

final reminderBridgeProvider = Provider<ReminderBridge>((ref) => ReminderBridge());

final fileBridgeProvider = Provider<FileBridge>((ref) => FileBridge());

/// Strings for code that runs without a BuildContext (seed data,
/// notifications scheduled from controllers).
final appStringsProvider = Provider<AppLocalizations>(
  (ref) => lookupAppLocalizations(appLocale),
);

extension AsyncValueData<T> on AsyncValue<T> {
  /// The latest value, also while refreshing; null if none yet.
  T? get dataOrNull => hasValue ? requireValue : null;
}
