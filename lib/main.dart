import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:gsu_fit/app.dart';
import 'package:gsu_fit/core/database/app_database.dart';
import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/media/media_cache.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/settings/data/sqlite_settings_repository.dart';
import 'package:gsu_fit/seed/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = appLocale.languageCode;
  await initializeDateFormatting(appLocale.languageCode);

  try {
    final database = await AppDatabase.open();
    await SeedService(database).seedIfNeeded(lookupAppLocalizations(appLocale));
    final settings = await SqliteSettingsRepository(database).load();
    final mediaCache = await MediaCache.create();

    runApp(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          mediaCacheProvider.overrideWithValue(mediaCache),
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
