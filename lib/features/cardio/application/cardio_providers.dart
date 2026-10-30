import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/cardio/data/sqlite_cardio_repository.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';

final cardioRepositoryProvider = Provider<CardioRepository>(
  (ref) => SqliteCardioRepository(ref.watch(appDatabaseProvider)),
);

final cardioSessionsProvider = FutureProvider<List<CardioSession>>(
  (ref) => ref.watch(cardioRepositoryProvider).getAll(),
);
