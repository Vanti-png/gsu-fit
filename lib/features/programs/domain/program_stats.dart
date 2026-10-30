import 'dart:math';

import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';

class ProgramProgress {
  const ProgramProgress({
    required this.completedThisWeek,
    required this.plannedPerWeek,
    required this.completedTotal,
    required this.plannedTotal,
  });

  final int completedThisWeek;
  final int plannedPerWeek;
  final int completedTotal;
  final int plannedTotal;

  double get weekFraction =>
      plannedPerWeek == 0 ? 0.0 : min(1.0, completedThisWeek / plannedPerWeek);

  double get totalFraction => plannedTotal == 0 ? 0.0 : min(1.0, completedTotal / plannedTotal);
}

/// Completion of [program]: this week's sessions against its day count and
/// all sessions since the start against days × weeks.
ProgramProgress programProgress(Program program, List<Workout> workouts, DateTime now) {
  final weekStart = startOfWeek(now);
  final start = dateOnly(program.startDate);
  var thisWeek = 0;
  var total = 0;
  for (final workout in workouts) {
    if (!workout.isFinished || workout.programId != program.id) continue;
    if (!workout.startedAt.isBefore(start)) total++;
    if (!workout.startedAt.isBefore(weekStart)) thisWeek++;
  }
  return ProgramProgress(
    completedThisWeek: thisWeek,
    plannedPerWeek: program.days.length,
    completedTotal: total,
    plannedTotal: program.days.length * program.durationWeeks,
  );
}

/// The day after the last one trained, cycling through the program.
ProgramDay? nextProgramDay(Program program, List<Workout> workouts) {
  if (program.days.isEmpty) return null;
  final days = [...program.days]..sort((a, b) => a.position.compareTo(b.position));
  Workout? latest;
  for (final workout in workouts) {
    if (!workout.isFinished || workout.programId != program.id) continue;
    if (latest == null || workout.startedAt.isAfter(latest.startedAt)) latest = workout;
  }
  if (latest == null) return days.first;
  final index = days.indexWhere((d) => d.id == latest!.programDayId);
  if (index < 0) return days.first;
  return days[(index + 1) % days.length];
}

/// Whether a session of [program] was finished today.
bool trainedToday(Program program, List<Workout> workouts, DateTime now) => workouts.any(
    (w) => w.isFinished && w.programId == program.id && isSameDay(w.startedAt, now));
