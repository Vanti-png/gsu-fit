import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';
import 'package:gsu_fit/features/programs/application/program_providers.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/progression.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';
import 'package:gsu_fit/features/workout/domain/workout_stats.dart';

class ActiveWorkoutState {
  const ActiveWorkoutState({
    required this.workout,
    required this.isManual,
    this.restEndsAt,
    this.restTotalSeconds = 0,
    this.suggestions = const {},
    this.targets = const {},
  });

  final Workout workout;

  /// Logging a past workout: no clock, no rest timer, editable date.
  final bool isManual;
  final DateTime? restEndsAt;
  final int restTotalSeconds;

  /// Progressive-overload suggestion per exercise id.
  final Map<String, ProgressionSuggestion> suggestions;

  /// Program prescription per exercise id, for "3 × 8–12" hints.
  final Map<String, ProgramExercise> targets;

  ActiveWorkoutState copyWith({
    Workout? workout,
    DateTime? restEndsAt,
    int? restTotalSeconds,
    bool clearRest = false,
  }) {
    return ActiveWorkoutState(
      workout: workout ?? this.workout,
      isManual: isManual,
      restEndsAt: clearRest ? null : (restEndsAt ?? this.restEndsAt),
      restTotalSeconds: clearRest ? 0 : (restTotalSeconds ?? this.restTotalSeconds),
      suggestions: suggestions,
      targets: targets,
    );
  }
}

final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutController, ActiveWorkoutState?>(ActiveWorkoutController.new);

/// Runs the workout in progress. Every change is written straight to the
/// database (with `ended_at` still empty), so a session survives the app
/// being closed or killed and can be resumed from the home screen.
class ActiveWorkoutController extends Notifier<ActiveWorkoutState?> {
  @override
  ActiveWorkoutState? build() => null;

  WorkoutRepository get _repository => ref.read(workoutRepositoryProvider);

  Future<void> startFromProgramDay({
    required Program program,
    required ProgramDay day,
    required String name,
  }) async {
    final history = await ref.read(workoutsProvider.future);
    final exercises = await ref.read(exerciseMapProvider.future);
    final unit = ref.read(settingsProvider).weightUnit;
    final calculator = ProgressionCalculator(roundingStepKg: unit.plateStepKg);

    final workoutId = newId();
    final sets = <WorkoutSet>[];
    final suggestions = <String, ProgressionSuggestion>{};
    final targets = <String, ProgramExercise>{};
    final items = [...day.exercises]..sort((a, b) => a.position.compareTo(b.position));
    for (var order = 0; order < items.length; order++) {
      final item = items[order];
      final exercise = exercises[item.exerciseId];
      final suggestion = calculator.suggest(
        target: item,
        history: exerciseHistory(history, item.exerciseId),
        bodyweight: exercise?.usesBodyweight ?? false,
        repStep: (exercise?.isTimed ?? false) ? 5 : 1,
      );
      suggestions[item.exerciseId] = suggestion;
      targets[item.exerciseId] = item;
      for (var index = 0; index < item.sets; index++) {
        sets.add(WorkoutSet(
          id: newId(),
          workoutId: workoutId,
          exerciseId: item.exerciseId,
          exerciseOrder: order,
          setIndex: index,
          reps: suggestion.reps,
          weightKg: suggestion.weightKg,
          targetReps: suggestion.reps,
          restSeconds: item.restSeconds,
        ));
      }
    }

    final workout = Workout(
      id: workoutId,
      name: name,
      programId: program.id,
      programDayId: day.id,
      startedAt: DateTime.now(),
      sets: sets,
    );
    await _repository.saveFull(workout);
    state = ActiveWorkoutState(
      workout: workout,
      isManual: false,
      suggestions: suggestions,
      targets: targets,
    );
    ref.invalidate(unfinishedWorkoutProvider);
  }

  /// Starts an empty session; with [manual] it logs a past workout instead.
  Future<void> startEmpty({required String name, bool manual = false}) async {
    final now = DateTime.now();
    final workout = Workout(
      id: newId(),
      name: name,
      startedAt: manual ? now.subtract(const Duration(hours: 1)) : now,
    );
    await _repository.saveFull(workout);
    state = ActiveWorkoutState(workout: workout, isManual: manual);
    ref.invalidate(unfinishedWorkoutProvider);
  }

  Future<void> resume(Workout workout) async {
    final targets = <String, ProgramExercise>{};
    if (workout.programDayId != null) {
      final programs = await ref.read(programsProvider.future);
      for (final program in programs) {
        for (final day in program.days) {
          if (day.id != workout.programDayId) continue;
          for (final item in day.exercises) {
            targets[item.exerciseId] = item;
          }
        }
      }
    }
    state = ActiveWorkoutState(workout: workout, isManual: false, targets: targets);
  }

  void _replaceSets(List<WorkoutSet> sets) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(workout: current.workout.copyWith(sets: sets));
  }

  Future<void> updateSet(WorkoutSet updated) async {
    final current = state;
    if (current == null) return;
    _replaceSets([
      for (final set in current.workout.sets) set.id == updated.id ? updated : set,
    ]);
    await _repository.saveSet(updated);
  }

  /// Ticks a set off and starts the rest timer.
  Future<void> toggleComplete(WorkoutSet set) async {
    final updated = set.copyWith(completed: !set.completed);
    await updateSet(updated);
    final current = state;
    if (updated.completed && current != null && !current.isManual) {
      startRest(updated.restSeconds);
    }
  }

  int _nextOrder(Workout workout) => workout.sets.isEmpty
      ? 0
      : workout.sets.map((s) => s.exerciseOrder).reduce(max) + 1;

  Future<void> addSet(String exerciseId) async {
    final current = state;
    if (current == null) return;
    final existing = current.workout.setsFor(exerciseId);
    final last = existing.isEmpty ? null : existing.last;
    final set = WorkoutSet(
      id: newId(),
      workoutId: current.workout.id,
      exerciseId: exerciseId,
      exerciseOrder: last?.exerciseOrder ?? _nextOrder(current.workout),
      setIndex: (last?.setIndex ?? -1) + 1,
      reps: last?.reps ?? 10,
      weightKg: last?.weightKg ?? 0,
      completed: current.isManual,
      restSeconds: last?.restSeconds ?? ref.read(settingsProvider).defaultRestSeconds,
    );
    _replaceSets([...current.workout.sets, set]);
    await _repository.saveSet(set);
  }

  Future<void> removeSet(WorkoutSet set) async {
    final current = state;
    if (current == null) return;
    _replaceSets(current.workout.sets.where((s) => s.id != set.id).toList());
    await _repository.deleteSet(set.id);
  }

  /// Adds [exercise] with three sets, pre-filled from its last session.
  Future<void> addExercise(Exercise exercise) async {
    final current = state;
    if (current == null) return;
    final history = await ref.read(workoutsProvider.future);
    final previous = lastSessionSets(history, exercise.id);
    final order = _nextOrder(current.workout);
    final rest = ref.read(settingsProvider).defaultRestSeconds;
    final added = [
      for (var index = 0; index < 3; index++)
        WorkoutSet(
          id: newId(),
          workoutId: current.workout.id,
          exerciseId: exercise.id,
          exerciseOrder: order,
          setIndex: index,
          reps: previous.isNotEmpty ? previous.last.reps : (exercise.isTimed ? 30 : 10),
          weightKg: previous.isNotEmpty ? previous.last.weightKg : 0,
          completed: current.isManual,
          restSeconds: rest,
        ),
    ];
    final latest = state;
    if (latest == null) return;
    _replaceSets([...latest.workout.sets, ...added]);
    for (final set in added) {
      await _repository.saveSet(set);
    }
  }

  Future<void> removeExercise(String exerciseId) async {
    final current = state;
    if (current == null) return;
    final removed = current.workout.sets.where((s) => s.exerciseId == exerciseId).toList();
    _replaceSets(current.workout.sets.where((s) => s.exerciseId != exerciseId).toList());
    for (final set in removed) {
      await _repository.deleteSet(set.id);
    }
  }

  void startRest(int seconds) {
    final current = state;
    if (current == null || seconds <= 0) return;
    final endsAt = DateTime.now().add(Duration(seconds: seconds));
    state = current.copyWith(restEndsAt: endsAt, restTotalSeconds: seconds);
    _scheduleRestNotification(endsAt);
  }

  void adjustRest(int deltaSeconds) {
    final current = state;
    final endsAt = current?.restEndsAt;
    if (current == null || endsAt == null) return;
    final updated = endsAt.add(Duration(seconds: deltaSeconds));
    if (!updated.isAfter(DateTime.now())) {
      skipRest();
      return;
    }
    state = current.copyWith(
      restEndsAt: updated,
      restTotalSeconds: max(1, current.restTotalSeconds + deltaSeconds),
    );
    _scheduleRestNotification(updated);
  }

  void skipRest() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(clearRest: true);
    ref.read(reminderBridgeProvider).cancel(ReminderScheduler.restTimerId);
  }

  /// Shows a notification when the rest is over in case the phone is
  /// locked; skipped silently when notifications are not allowed.
  Future<void> _scheduleRestNotification(DateTime at) async {
    final bridge = ref.read(reminderBridgeProvider);
    if (!await bridge.notificationsAllowed()) return;
    final l = ref.read(appStringsProvider);
    await bridge.scheduleOnce(
      id: ReminderScheduler.restTimerId,
      title: l.restOverTitle,
      body: l.restOverBody,
      at: at,
    );
  }

  /// Saves the session. Sets that were never ticked are dropped so history
  /// only holds work that was actually done.
  Future<Workout?> finish({required String notes, DateTime? startedAt, Duration? duration}) async {
    final current = state;
    if (current == null) return null;
    final start = startedAt ?? current.workout.startedAt;
    final length = duration ?? DateTime.now().difference(start);
    final done = current.workout.sets.where((s) => s.completed).toList();
    for (final set in current.workout.sets.where((s) => !s.completed)) {
      await _repository.deleteSet(set.id);
    }
    final finished = current.workout.copyWith(
      startedAt: start,
      endedAt: start.add(length),
      durationSeconds: length.inSeconds,
      notes: notes,
      sets: done,
    );
    await _repository.saveWorkout(finished);
    await ref.read(reminderBridgeProvider).cancel(ReminderScheduler.restTimerId);
    state = null;
    ref.invalidate(workoutsProvider);
    ref.invalidate(unfinishedWorkoutProvider);
    return finished;
  }

  Future<void> discard() async {
    final current = state;
    if (current == null) return;
    await _repository.deleteWorkout(current.workout.id);
    await ref.read(reminderBridgeProvider).cancel(ReminderScheduler.restTimerId);
    state = null;
    ref.invalidate(unfinishedWorkoutProvider);
  }
}
