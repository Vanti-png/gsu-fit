import 'dart:math';

import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/features/cardio/domain/calorie_calculator.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';
import 'package:gsu_fit/features/programs/domain/progression.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';

class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.workoutCount,
    required this.cardioCount,
    required this.trainingTime,
    required this.volumeKg,
    required this.cardioDistanceKm,
    required this.caloriesBurned,
    required this.activeWeekdays,
    required this.targetDays,
    required this.previousVolumeKg,
  });

  final DateTime weekStart;
  final int workoutCount;
  final int cardioCount;
  final Duration trainingTime;
  final double volumeKg;
  final double cardioDistanceKm;
  final double caloriesBurned;

  /// Weekdays (1 = Monday) with any training.
  final Set<int> activeWeekdays;
  final int targetDays;
  final double previousVolumeKg;

  double get targetFraction =>
      targetDays <= 0 ? 0.0 : min(1.0, activeWeekdays.length / targetDays);

  /// Change against last week as a fraction (0.1 = +10%); null without data.
  double? get volumeChange =>
      previousVolumeKg <= 0 ? null : (volumeKg - previousVolumeKg) / previousVolumeKg;
}

WeeklySummary buildWeeklySummary({
  required DateTime now,
  required List<Workout> workouts,
  required List<CardioSession> cardio,
  required double bodyWeightKg,
  required int targetDays,
}) {
  final weekStart = startOfWeek(now);
  final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  final previousStart = DateTime(weekStart.year, weekStart.month, weekStart.day - 7);

  bool inWeek(DateTime t) => !t.isBefore(weekStart) && t.isBefore(weekEnd);
  bool inPrevious(DateTime t) => !t.isBefore(previousStart) && t.isBefore(weekStart);

  var workoutCount = 0;
  var cardioCount = 0;
  var seconds = 0;
  var volume = 0.0;
  var previousVolume = 0.0;
  var distance = 0.0;
  var calories = 0.0;
  final weekdays = <int>{};

  for (final workout in workouts) {
    if (!workout.isFinished) continue;
    if (inPrevious(workout.startedAt)) previousVolume += workout.totalVolumeKg;
    if (!inWeek(workout.startedAt)) continue;
    workoutCount++;
    seconds += workout.durationSeconds;
    volume += workout.totalVolumeKg;
    calories += CalorieCalculator.strength(duration: workout.duration, weightKg: bodyWeightKg);
    weekdays.add(workout.startedAt.weekday);
  }
  for (final session in cardio) {
    if (!inWeek(session.startedAt)) continue;
    cardioCount++;
    seconds += session.durationSeconds;
    distance += session.distanceKm ?? 0;
    calories += session.calories;
    weekdays.add(session.startedAt.weekday);
  }

  return WeeklySummary(
    weekStart: weekStart,
    workoutCount: workoutCount,
    cardioCount: cardioCount,
    trainingTime: Duration(seconds: seconds),
    volumeKg: volume,
    cardioDistanceKm: distance,
    caloriesBurned: calories,
    activeWeekdays: weekdays,
    targetDays: targetDays,
    previousVolumeKg: previousVolume,
  );
}

class WeekVolume {
  const WeekVolume(this.weekStart, this.volumeKg);

  final DateTime weekStart;
  final double volumeKg;
}

/// Total training volume for each of the last [weeks] weeks, oldest first.
List<WeekVolume> weeklyVolumes(List<Workout> workouts, {required DateTime now, int weeks = 8}) {
  final current = startOfWeek(now);
  final result = <WeekVolume>[];
  for (var i = weeks - 1; i >= 0; i--) {
    final start = DateTime(current.year, current.month, current.day - 7 * i);
    final end = DateTime(start.year, start.month, start.day + 7);
    var volume = 0.0;
    for (final workout in workouts) {
      if (!workout.isFinished) continue;
      if (workout.startedAt.isBefore(start) || !workout.startedAt.isBefore(end)) continue;
      volume += workout.totalVolumeKg;
    }
    result.add(WeekVolume(start, volume));
  }
  return result;
}

/// Past sessions of one exercise as progression input, most recent first.
List<List<SetResult>> exerciseHistory(List<Workout> workouts, String exerciseId,
    {String? excludeWorkoutId}) {
  final finished = workouts
      .where((w) => w.isFinished && w.id != excludeWorkoutId)
      .toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final sessions = <List<SetResult>>[];
  for (final workout in finished) {
    final sets = workout.setsFor(exerciseId);
    if (sets.isEmpty) continue;
    sessions.add([
      for (final s in sets) SetResult(weightKg: s.weightKg, reps: s.reps, completed: s.completed),
    ]);
  }
  return sessions;
}

class ExerciseSessionStat {
  const ExerciseSessionStat({
    required this.date,
    required this.bestWeightKg,
    required this.bestOneRepMaxKg,
    required this.bestReps,
    required this.volumeKg,
  });

  final DateTime date;
  final double bestWeightKg;
  final double bestOneRepMaxKg;
  final int bestReps;
  final double volumeKg;
}

/// One entry per workout that contains [exerciseId], oldest first.
List<ExerciseSessionStat> exerciseSessionStats(List<Workout> workouts, String exerciseId) {
  final stats = <ExerciseSessionStat>[];
  for (final workout in workouts) {
    if (!workout.isFinished) continue;
    final sets = workout.setsFor(exerciseId).where((s) => s.completed).toList();
    if (sets.isEmpty) continue;
    stats.add(ExerciseSessionStat(
      date: workout.startedAt,
      bestWeightKg: sets.map((s) => s.weightKg).reduce(max),
      bestOneRepMaxKg: sets.map((s) => estimateOneRepMax(s.weightKg, s.reps)).reduce(max),
      bestReps: sets.map((s) => s.reps).reduce(max),
      volumeKg: sets.fold(0.0, (sum, s) => sum + s.volumeKg),
    ));
  }
  stats.sort((a, b) => a.date.compareTo(b.date));
  return stats;
}

/// The most recent completed sets of [exerciseId], for "last time" hints.
List<WorkoutSet> lastSessionSets(List<Workout> workouts, String exerciseId,
    {String? excludeWorkoutId}) {
  Workout? latest;
  for (final workout in workouts) {
    if (!workout.isFinished || workout.id == excludeWorkoutId) continue;
    if (workout.setsFor(exerciseId).every((s) => !s.completed)) continue;
    if (latest == null || workout.startedAt.isAfter(latest.startedAt)) latest = workout;
  }
  if (latest == null) return const [];
  return latest.setsFor(exerciseId).where((s) => s.completed).toList();
}
