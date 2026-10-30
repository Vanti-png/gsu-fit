import 'package:gsu_fit/core/utils/map_read.dart';

class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.exerciseOrder,
    required this.setIndex,
    this.reps = 0,
    this.weightKg = 0,
    this.completed = false,
    this.targetReps,
    this.restSeconds = 90,
    this.createdAt,
  });

  final String id;
  final String workoutId;
  final String exerciseId;

  /// Position of the exercise within the workout.
  final int exerciseOrder;
  final int setIndex;

  /// Repetitions, or seconds for timed exercises.
  final int reps;
  final double weightKg;
  final bool completed;
  final int? targetReps;
  final int restSeconds;
  final DateTime? createdAt;

  /// Training volume (weight × reps) of a completed set.
  double get volumeKg => completed ? weightKg * reps : 0;

  WorkoutSet copyWith({
    int? exerciseOrder,
    int? setIndex,
    int? reps,
    double? weightKg,
    bool? completed,
    int? restSeconds,
  }) {
    return WorkoutSet(
      id: id,
      workoutId: workoutId,
      exerciseId: exerciseId,
      exerciseOrder: exerciseOrder ?? this.exerciseOrder,
      setIndex: setIndex ?? this.setIndex,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      completed: completed ?? this.completed,
      targetReps: targetReps,
      restSeconds: restSeconds ?? this.restSeconds,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'workout_id': workoutId,
        'exercise_id': exerciseId,
        'exercise_order': exerciseOrder,
        'set_index': setIndex,
        'reps': reps,
        'weight_kg': weightKg,
        'completed': completed ? 1 : 0,
        'target_reps': targetReps,
        'rest_seconds': restSeconds,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory WorkoutSet.fromMap(Map<String, Object?> map) => WorkoutSet(
        id: map['id']! as String,
        workoutId: map['workout_id']! as String,
        exerciseId: map['exercise_id']! as String,
        exerciseOrder: readInt(map['exercise_order']) ?? 0,
        setIndex: readInt(map['set_index']) ?? 0,
        reps: readInt(map['reps']) ?? 0,
        weightKg: readDouble(map['weight_kg']) ?? 0,
        completed: readBool(map['completed']),
        targetReps: readInt(map['target_reps']),
        restSeconds: readInt(map['rest_seconds']) ?? 90,
        createdAt: readDate(map['created_at']),
      );
}

class Workout {
  const Workout({
    required this.id,
    required this.name,
    this.programId,
    this.programDayId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.notes = '',
    this.sets = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String? programId;
  final String? programDayId;
  final DateTime startedAt;

  /// Null while the workout is in progress.
  final DateTime? endedAt;
  final int durationSeconds;
  final String notes;
  final List<WorkoutSet> sets;
  final DateTime? createdAt;

  bool get isFinished => endedAt != null;

  Duration get duration => Duration(seconds: durationSeconds);

  /// Exercise ids in the order they appear in the workout.
  List<String> get exerciseIds {
    final sorted = [...sets]
      ..sort((a, b) => a.exerciseOrder != b.exerciseOrder
          ? a.exerciseOrder.compareTo(b.exerciseOrder)
          : a.setIndex.compareTo(b.setIndex));
    final ids = <String>[];
    for (final set in sorted) {
      if (!ids.contains(set.exerciseId)) ids.add(set.exerciseId);
    }
    return ids;
  }

  List<WorkoutSet> setsFor(String exerciseId) =>
      sets.where((s) => s.exerciseId == exerciseId).toList()
        ..sort((a, b) => a.setIndex.compareTo(b.setIndex));

  double get totalVolumeKg => sets.fold(0.0, (sum, s) => sum + s.volumeKg);

  int get completedSetCount => sets.where((s) => s.completed).length;

  Workout copyWith({
    String? name,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? notes,
    List<WorkoutSet>? sets,
  }) {
    return Workout(
      id: id,
      name: name ?? this.name,
      programId: programId,
      programDayId: programDayId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      notes: notes ?? this.notes,
      sets: sets ?? this.sets,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'program_id': programId,
        'program_day_id': programDayId,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'duration_seconds': durationSeconds,
        'notes': notes,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory Workout.fromMap(Map<String, Object?> map, {List<WorkoutSet> sets = const []}) =>
      Workout(
        id: map['id']! as String,
        name: readString(map['name']) ?? '',
        programId: readString(map['program_id']),
        programDayId: readString(map['program_day_id']),
        startedAt: readDate(map['started_at']) ?? DateTime.now(),
        endedAt: readDate(map['ended_at']),
        durationSeconds: readInt(map['duration_seconds']) ?? 0,
        notes: readString(map['notes']) ?? '',
        sets: sets,
        createdAt: readDate(map['created_at']),
      );
}

abstract interface class WorkoutRepository {
  /// Finished workouts with their sets, newest first.
  Future<List<Workout>> getFinished();

  /// The workout left open when the app was closed mid-session, if any.
  Future<Workout?> getUnfinished();

  Future<void> saveFull(Workout workout);

  Future<void> saveWorkout(Workout workout);

  Future<void> saveSet(WorkoutSet set);

  Future<void> deleteSet(String setId);

  Future<void> deleteWorkout(String workoutId);
}
