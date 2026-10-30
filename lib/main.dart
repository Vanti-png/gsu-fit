import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:gsu_fit/app.dart';
import 'package:gsu_fit/core/database/app_database.dart';
import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/media/media_cache.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/core/web_store/persistence_stub.dart'
    if (dart.library.js_interop) 'package:gsu_fit/core/web_store/persistence_web.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/programs/application/program_providers.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/seed/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = appLocale.languageCode;
  await initializeDateFormatting(appLocale.languageCode);

  try {
    // Android keeps data in SQLite; the web build in the browser's storage.
    final List<Override> storage = kIsWeb
        ? [
            jsonStoreProvider.overrideWithValue(JsonStore(createBrowserPersistence())),
            mediaCacheProvider.overrideWithValue(MediaCache.disabled()),
          ]
        : [
            appDatabaseProvider.overrideWithValue(await AppDatabase.open()),
            mediaCacheProvider.overrideWithValue(await MediaCache.create()),
          ];

    final bootstrap = ProviderContainer(overrides: storage);
    await SeedService(
      settings: bootstrap.read(settingsRepositoryProvider),
      exercises: bootstrap.read(exerciseRepositoryProvider),
      programs: bootstrap.read(programRepositoryProvider),
    ).seedIfNeeded(lookupAppLocalizations(appLocale));
    final settings = await bootstrap.read(settingsRepositoryProvider).load();
    bootstrap.dispose();

    runApp(
      ProviderScope(
        overrides: [
          ...storage,
          initialSettingsProvider.overrideWithValue(settings),
        ],
        child: const GsuFitApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Startup failed: $error\n$stackTrace');
    runApp(const StartupErrorApp());
  }
}
