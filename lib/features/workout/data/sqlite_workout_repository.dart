import 'package:gsu_fit/core/database/sqlite_store.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';

class SqliteWorkoutRepository extends SqliteStore implements WorkoutRepository {
  SqliteWorkoutRepository(super.database);

  static const String _workouts = 'workouts';
  static const String _sets = 'workout_sets';

  Future<List<Workout>> _load({required bool finished}) async {
    final rows = await queryActive(
      _workouts,
      where: finished ? 'ended_at IS NOT NULL' : 'ended_at IS NULL',
      orderBy: 'started_at DESC',
    );
    if (rows.isEmpty) return const [];
    final setRows = await queryActive(
      _sets,
      where: 'workout_id IN (SELECT id FROM $_workouts WHERE deleted_at IS NULL AND '
          '${finished ? 'ended_at IS NOT NULL' : 'ended_at IS NULL'})',
      orderBy: 'exercise_order, set_index',
    );
    final setsByWorkout = <String, List<WorkoutSet>>{};
    for (final row in setRows) {
      final set = WorkoutSet.fromMap(row);
      setsByWorkout.putIfAbsent(set.workoutId, () => []).add(set);
    }
    return [
      for (final row in rows) Workout.fromMap(row, sets: setsByWorkout[row['id']] ?? const []),
    ];
  }

  @override
  Future<List<Workout>> getFinished() => _load(finished: true);

  @override
  Future<Workout?> getUnfinished() async {
    final open = await _load(finished: false);
    return open.isEmpty ? null : open.first;
  }

  @override
  Future<void> saveFull(Workout workout) {
    return db.transaction((txn) async {
      await upsertRow(_workouts, workout.toMap(), executor: txn);
      for (final set in workout.sets) {
        await upsertRow(_sets, set.toMap(), executor: txn);
      }
    });
  }

  @override
  Future<void> saveWorkout(Workout workout) => upsertRow(_workouts, workout.toMap());

  @override
  Future<void> saveSet(WorkoutSet set) => upsertRow(_sets, set.toMap());

  @override
  Future<void> deleteSet(String setId) => softDelete(_sets, where: 'id = ?', whereArgs: [setId]);

  @override
  Future<void> deleteWorkout(String workoutId) {
    return db.transaction((txn) async {
      await softDelete(_sets, where: 'workout_id = ?', whereArgs: [workoutId], executor: txn);
      await softDelete(_workouts, where: 'id = ?', whereArgs: [workoutId], executor: txn);
    });
  }
}
