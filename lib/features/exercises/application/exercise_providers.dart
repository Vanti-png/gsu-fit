import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:gsu_fit/features/exercises/data/web_exercise_repository.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => kIsWeb
      ? WebExerciseRepository(ref.watch(jsonStoreProvider))
      : SqliteExerciseRepository(ref.watch(appDatabaseProvider)),
);

/// Library contents (deleted custom exercises excluded).
final exercisesProvider = FutureProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).getAll(),
);

/// Lookup by id, including deleted exercises so history keeps its names.
final exerciseMapProvider = FutureProvider<Map<String, Exercise>>((ref) async {
  // Refresh together with the library list.
  ref.watch(exercisesProvider);
  final all = await ref.watch(exerciseRepositoryProvider).getAll(includeDeleted: true);
  return {for (final exercise in all) exercise.id: exercise};
});
