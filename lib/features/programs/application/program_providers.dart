import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/programs/data/sqlite_program_repository.dart';
import 'package:gsu_fit/features/programs/data/web_program_repository.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';

final programRepositoryProvider = Provider<ProgramRepository>(
  (ref) => kIsWeb
      ? WebProgramRepository(ref.watch(jsonStoreProvider))
      : SqliteProgramRepository(ref.watch(appDatabaseProvider)),
);

final programsProvider = FutureProvider<List<Program>>(
  (ref) => ref.watch(programRepositoryProvider).getAll(),
);

final activeProgramProvider = FutureProvider<Program?>((ref) async {
  final programs = await ref.watch(programsProvider.future);
  return programs.where((p) => p.isActive).firstOrNull;
});
