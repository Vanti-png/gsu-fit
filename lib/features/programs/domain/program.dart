import 'package:gsu_fit/core/utils/map_read.dart';

enum ProgramSplit { fullBody, upperLower, pushPullLegs, hybrid, custom }

/// One exercise slot of a program day with its prescription.
class ProgramExercise {
  const ProgramExercise({
    required this.id,
    required this.dayId,
    required this.exerciseId,
    required this.position,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.restSeconds,
    this.startWeightKg = 0,
    this.incrementKg = 2.5,
    this.createdAt,
  });

  final String id;
  final String dayId;
  final String exerciseId;
  final int position;
  final int sets;

  /// Rep range for double progression (seconds for timed exercises).
  final int minReps;
  final int maxReps;
  final int restSeconds;

  /// Weight for the first session; 0 means "pick a comfortable weight".
  final double startWeightKg;

  /// Load added once every set reaches [maxReps].
  final double incrementKg;
  final DateTime? createdAt;

  ProgramExercise copyWith({
    String? dayId,
    String? exerciseId,
    int? position,
    int? sets,
    int? minReps,
    int? maxReps,
    int? restSeconds,
    double? startWeightKg,
    double? incrementKg,
  }) {
    return ProgramExercise(
      id: id,
      dayId: dayId ?? this.dayId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      sets: sets ?? this.sets,
      minReps: minReps ?? this.minReps,
      maxReps: maxReps ?? this.maxReps,
      restSeconds: restSeconds ?? this.restSeconds,
      startWeightKg: startWeightKg ?? this.startWeightKg,
      incrementKg: incrementKg ?? this.incrementKg,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'day_id': dayId,
        'exercise_id': exerciseId,
        'position': position,
        'sets': sets,
        'min_reps': minReps,
        'max_reps': maxReps,
        'rest_seconds': restSeconds,
        'start_weight_kg': startWeightKg,
        'increment_kg': incrementKg,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory ProgramExercise.fromMap(Map<String, Object?> map) => ProgramExercise(
        id: map['id']! as String,
        dayId: map['day_id']! as String,
        exerciseId: map['exercise_id']! as String,
        position: readInt(map['position']) ?? 0,
        sets: readInt(map['sets']) ?? 3,
        minReps: readInt(map['min_reps']) ?? 8,
        maxReps: readInt(map['max_reps']) ?? 12,
        restSeconds: readInt(map['rest_seconds']) ?? 90,
        startWeightKg: readDouble(map['start_weight_kg']) ?? 0,
        incrementKg: readDouble(map['increment_kg']) ?? 2.5,
        createdAt: readDate(map['created_at']),
      );
}

class ProgramDay {
  const ProgramDay({
    required this.id,
    required this.programId,
    required this.name,
    required this.position,
    this.exercises = const [],
    this.createdAt,
  });

  final String id;
  final String programId;
  final String name;
  final int position;
  final List<ProgramExercise> exercises;
  final DateTime? createdAt;

  ProgramDay copyWith({String? name, int? position, List<ProgramExercise>? exercises}) {
    return ProgramDay(
      id: id,
      programId: programId,
      name: name ?? this.name,
      position: position ?? this.position,
      exercises: exercises ?? this.exercises,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'program_id': programId,
        'name': name,
        'position': position,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory ProgramDay.fromMap(
    Map<String, Object?> map, {
    List<ProgramExercise> exercises = const [],
  }) =>
      ProgramDay(
        id: map['id']! as String,
        programId: map['program_id']! as String,
        name: readString(map['name']) ?? '',
        position: readInt(map['position']) ?? 0,
        exercises: exercises,
        createdAt: readDate(map['created_at']),
      );
}

class Program {
  const Program({
    required this.id,
    required this.name,
    this.description = '',
    required this.split,
    this.isActive = false,
    this.durationWeeks = 8,
    required this.startDate,
    this.days = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final ProgramSplit split;
  final bool isActive;
  final int durationWeeks;
  final DateTime startDate;

  /// Training days in rotation order; not tied to fixed weekdays.
  final List<ProgramDay> days;
  final DateTime? createdAt;

  int get exerciseCount => days.fold(0, (sum, day) => sum + day.exercises.length);

  Program copyWith({
    String? name,
    String? description,
    ProgramSplit? split,
    bool? isActive,
    int? durationWeeks,
    DateTime? startDate,
    List<ProgramDay>? days,
  }) {
    return Program(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      split: split ?? this.split,
      isActive: isActive ?? this.isActive,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      startDate: startDate ?? this.startDate,
      days: days ?? this.days,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'split': split.name,
        'is_active': isActive ? 1 : 0,
        'duration_weeks': durationWeeks,
        'start_date': startDate.millisecondsSinceEpoch,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory Program.fromMap(Map<String, Object?> map, {List<ProgramDay> days = const []}) =>
      Program(
        id: map['id']! as String,
        name: readString(map['name']) ?? '',
        description: readString(map['description']) ?? '',
        split: readEnum(ProgramSplit.values, map['split'], ProgramSplit.custom),
        isActive: readBool(map['is_active']),
        durationWeeks: readInt(map['duration_weeks']) ?? 8,
        startDate: readDate(map['start_date']) ?? DateTime.now(),
        days: days,
        createdAt: readDate(map['created_at']),
      );
}

abstract interface class ProgramRepository {
  /// Programs with their days and exercises, active program first.
  Future<List<Program>> getAll();

  /// Saves the program, its days and their exercises in one transaction.
  Future<void> saveFull(Program program);

  Future<void> saveProgram(Program program);

  Future<void> setActive(String programId);

  Future<void> deleteProgram(String programId);

  Future<void> saveDay(ProgramDay day);

  Future<void> deleteDay(String dayId);

  Future<void> saveProgramExercise(ProgramExercise exercise);

  Future<void> saveProgramExercises(List<ProgramExercise> exercises);

  Future<void> deleteProgramExercise(String id);
}
