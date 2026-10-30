import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/cardio/data/sqlite_cardio_repository.dart';
import 'package:gsu_fit/features/cardio/data/web_cardio_repository.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';

final cardioRepositoryProvider = Provider<CardioRepository>(
  (ref) => kIsWeb
      ? WebCardioRepository(ref.watch(jsonStoreProvider))
      : SqliteCardioRepository(ref.watch(appDatabaseProvider)),
);

final cardioSessionsProvider = FutureProvider<List<CardioSession>>(
  (ref) => ref.watch(cardioRepositoryProvider).getAll(),
);
