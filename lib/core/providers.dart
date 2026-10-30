import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/database/app_database.dart';
import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/media/media_cache.dart';
import 'package:gsu_fit/core/platform/native_bridge.dart';

/// Opened in main() before the first frame and injected via overrides.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider is overridden in main()'),
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
