import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/cardio/application/cardio_providers.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/workout/data/sqlite_workout_repository.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';
import 'package:gsu_fit/features/workout/domain/workout_stats.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => SqliteWorkoutRepository(ref.watch(appDatabaseProvider)),
);

/// Finished workouts, newest first.
final workoutsProvider = FutureProvider<List<Workout>>(
  (ref) => ref.watch(workoutRepositoryProvider).getFinished(),
);

final unfinishedWorkoutProvider = FutureProvider<Workout?>(
  (ref) => ref.watch(workoutRepositoryProvider).getUnfinished(),
);

final weeklySummaryProvider = FutureProvider<WeeklySummary>((ref) async {
  final workouts = await ref.watch(workoutsProvider.future);
  final cardio = await ref.watch(cardioSessionsProvider.future);
  final profile = await ref.watch(profileProvider.future);
  return buildWeeklySummary(
    now: DateTime.now(),
    workouts: workouts,
    cardio: cardio,
    bodyWeightKg: profile?.weightKg ?? 70,
    targetDays: profile?.daysPerWeek ?? 3,
  );
});
