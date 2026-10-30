import 'package:flutter_test/flutter_test.dart';

import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/program_stats.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';
import 'package:gsu_fit/features/workout/domain/workout_stats.dart';

// Wednesday 2026-10-28; that week starts on Monday 2026-10-26.
final now = DateTime(2026, 10, 28, 18);

Workout workout(
  String id,
  DateTime start, {
  String? programId,
  String? dayId,
  List<(String, double, int)> sets = const [],
  bool finished = true,
}) {
  return Workout(
    id: id,
    name: id,
    programId: programId,
    programDayId: dayId,
    startedAt: start,
    endedAt: finished ? start.add(const Duration(hours: 1)) : null,
    durationSeconds: 3600,
    sets: [
      for (var i = 0; i < sets.length; i++)
        WorkoutSet(
          id: '$id-$i',
          workoutId: id,
          exerciseId: sets[i].$1,
          exerciseOrder: 0,
          setIndex: i,
          weightKg: sets[i].$2,
          reps: sets[i].$3,
          completed: true,
        ),
    ],
  );
}

Program program() {
  ProgramDay day(String id, int position) =>
      ProgramDay(id: id, programId: 'prog', name: id, position: position);
  return Program(
    id: 'prog',
    name: 'Test',
    split: ProgramSplit.fullBody,
    startDate: DateTime(2026, 10, 1),
    durationWeeks: 4,
    days: [day('A', 0), day('B', 1), day('C', 2)],
  );
}

void main() {
  group('dates', () {
    test('startOfWeek is Monday at midnight', () {
      expect(startOfWeek(now), DateTime(2026, 10, 26));
      expect(startOfWeek(DateTime(2026, 11, 1, 23)), DateTime(2026, 10, 26));
    });

    test('dayKey round trip', () {
      expect(dayKey(DateTime(2026, 3, 7, 15)), '2026-03-07');
      expect(parseDayKey('2026-03-07'), DateTime(2026, 3, 7));
    });

    test('formatClock', () {
      expect(formatClock(const Duration(seconds: 65)), '01:05');
      expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(formatClock(const Duration(seconds: -5)), '00:00');
    });
  });

  group('WorkoutSet volume', () {
    test('counts only completed sets', () {
      const done = WorkoutSet(
        id: 's', workoutId: 'w', exerciseId: 'e', exerciseOrder: 0, setIndex: 0,
        reps: 10, weightKg: 50, completed: true,
      );
      expect(done.volumeKg, 500);
      expect(done.copyWith(completed: false).volumeKg, 0);
    });
  });

  group('buildWeeklySummary', () {
    test('only counts this week and compares volume with last week', () {
      final summary = buildWeeklySummary(
        now: now,
        workouts: [
          workout('mon', DateTime(2026, 10, 26, 9), sets: [('squat', 100, 5), ('squat', 100, 5)]),
          workout('wed', DateTime(2026, 10, 28, 9), sets: [('bench', 50, 10)]),
          workout('lastWeek', DateTime(2026, 10, 20, 9), sets: [('squat', 100, 10)]),
          workout('open', DateTime(2026, 10, 28, 17), finished: false, sets: [('squat', 200, 5)]),
        ],
        cardio: [
          CardioSession(
            id: 'run',
            type: CardioType.running,
            startedAt: DateTime(2026, 10, 27, 7),
            durationSeconds: 1800,
            distanceKm: 5,
            calories: 300,
          ),
          CardioSession(
            id: 'old',
            type: CardioType.running,
            startedAt: DateTime(2026, 10, 19, 7),
            durationSeconds: 1800,
            calories: 300,
          ),
        ],
        bodyWeightKg: 80,
        targetDays: 4,
      );
      expect(summary.workoutCount, 2);
      expect(summary.cardioCount, 1);
      expect(summary.volumeKg, 1500);
      expect(summary.previousVolumeKg, 1000);
      expect(summary.volumeChange, closeTo(0.5, 0.0001));
      expect(summary.activeWeekdays, {1, 2, 3});
      expect(summary.targetFraction, closeTo(0.75, 0.0001));
      expect(summary.cardioDistanceKm, 5);
      expect(summary.trainingTime, const Duration(hours: 2, minutes: 30));
      // 2 × (5 MET × 80 kg × 1 h) + 300
      expect(summary.caloriesBurned, closeTo(1100, 0.001));
    });

    test('volume change is null without last week data', () {
      final summary = buildWeeklySummary(
        now: now,
        workouts: [workout('w', DateTime(2026, 10, 27), sets: [('e', 10, 10)])],
        cardio: const [],
        bodyWeightKg: 70,
        targetDays: 3,
      );
      expect(summary.volumeChange, isNull);
    });
  });

  test('weeklyVolumes returns one bucket per week, oldest first', () {
    final volumes = weeklyVolumes(
      [
        workout('a', DateTime(2026, 10, 27), sets: [('e', 10, 10)]),
        workout('b', DateTime(2026, 10, 14), sets: [('e', 20, 10)]),
      ],
      now: now,
      weeks: 3,
    );
    expect(volumes.map((v) => v.weekStart), [
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 26),
    ]);
    expect(volumes.map((v) => v.volumeKg), [200, 0, 100]);
  });

  test('exerciseHistory is most recent first and skips other exercises', () {
    final history = exerciseHistory([
      workout('old', DateTime(2026, 10, 1), sets: [('squat', 80, 8)]),
      workout('new', DateTime(2026, 10, 20), sets: [('squat', 90, 8)]),
      workout('bench', DateTime(2026, 10, 25), sets: [('bench', 60, 8)]),
    ], 'squat');
    expect(history, hasLength(2));
    expect(history.first.first.weightKg, 90);
  });

  test('exerciseSessionStats tracks best weight and estimated 1RM', () {
    final stats = exerciseSessionStats([
      workout('w2', DateTime(2026, 10, 20), sets: [('squat', 100, 5), ('squat', 90, 10)]),
      workout('w1', DateTime(2026, 10, 10), sets: [('squat', 80, 5)]),
    ], 'squat');
    expect(stats.map((s) => s.date), [DateTime(2026, 10, 10), DateTime(2026, 10, 20)]);
    expect(stats.last.bestWeightKg, 100);
    expect(stats.last.bestOneRepMaxKg, closeTo(120, 0.001));
    expect(stats.last.volumeKg, 1400);
  });

  group('program progress', () {
    test('counts sessions this week and since the start', () {
      final progress = programProgress(
        program(),
        [
          workout('1', DateTime(2026, 10, 26), programId: 'prog', dayId: 'A'),
          workout('2', DateTime(2026, 10, 27), programId: 'prog', dayId: 'B'),
          workout('3', DateTime(2026, 10, 15), programId: 'prog', dayId: 'C'),
          workout('other', DateTime(2026, 10, 27), programId: 'x'),
        ],
        now,
      );
      expect(progress.completedThisWeek, 2);
      expect(progress.plannedPerWeek, 3);
      expect(progress.completedTotal, 3);
      expect(progress.plannedTotal, 12);
      expect(progress.weekFraction, closeTo(2 / 3, 0.0001));
      expect(progress.totalFraction, closeTo(0.25, 0.0001));
    });

    test('week fraction is capped at 100%', () {
      final progress = programProgress(
        program(),
        [
          for (var i = 0; i < 5; i++)
            workout('$i', DateTime(2026, 10, 26, 8 + i), programId: 'prog', dayId: 'A'),
        ],
        now,
      );
      expect(progress.weekFraction, 1);
    });

    test('next day follows the last finished one and wraps around', () {
      final p = program();
      expect(nextProgramDay(p, const [])!.id, 'A');
      expect(
        nextProgramDay(p, [workout('1', DateTime(2026, 10, 26), programId: 'prog', dayId: 'B')])!.id,
        'C',
      );
      expect(
        nextProgramDay(p, [
          workout('1', DateTime(2026, 10, 26), programId: 'prog', dayId: 'B'),
          workout('2', DateTime(2026, 10, 27), programId: 'prog', dayId: 'C'),
        ])!.id,
        'A',
      );
    });

    test('trainedToday', () {
      final p = program();
      expect(trainedToday(p, [workout('1', DateTime(2026, 10, 28, 7), programId: 'prog')], now), isTrue);
      expect(trainedToday(p, [workout('1', DateTime(2026, 10, 27, 7), programId: 'prog')], now), isFalse);
    });
  });
}
