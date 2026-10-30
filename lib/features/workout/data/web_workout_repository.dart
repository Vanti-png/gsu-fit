import 'package:gsu_fit/core/utils/map_read.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';

class WebWorkoutRepository implements WorkoutRepository {
  WebWorkoutRepository(this._store);

  final JsonStore _store;

  static const String _workouts = 'workouts';
  static const String _sets = 'workout_sets';

  List<Workout> _load({required bool finished}) {
    final rows = _store
        .rows(_workouts)
        .where((row) => (row['ended_at'] != null) == finished)
        .toList()
      ..sort((a, b) => (readInt(b['started_at']) ?? 0).compareTo(readInt(a['started_at']) ?? 0));
    if (rows.isEmpty) return const [];
    final ids = {for (final row in rows) row['id']};
    final sets = [
      for (final row in _store.rows(_sets))
        if (ids.contains(row['workout_id'])) WorkoutSet.fromMap(row),
    ]..sort((a, b) => a.exerciseOrder != b.exerciseOrder
        ? a.exerciseOrder.compareTo(b.exerciseOrder)
        : a.setIndex.compareTo(b.setIndex));
    final setsByWorkout = <String, List<WorkoutSet>>{};
    for (final set in sets) {
      setsByWorkout.putIfAbsent(set.workoutId, () => []).add(set);
    }
    return [
      for (final row in rows) Workout.fromMap(row, sets: setsByWorkout[row['id']] ?? const []),
    ];
  }

  @override
  Future<List<Workout>> getFinished() async => _load(finished: true);

  @override
  Future<Workout?> getUnfinished() async {
    final open = _load(finished: false);
    return open.isEmpty ? null : open.first;
  }

  @override
  Future<void> saveFull(Workout workout) async {
    _store.upsert(_workouts, workout.toMap());
    _store.upsertAll(_sets, workout.sets.map((s) => s.toMap()));
  }

  @override
  Future<void> saveWorkout(Workout workout) async => _store.upsert(_workouts, workout.toMap());

  @override
  Future<void> saveSet(WorkoutSet set) async => _store.upsert(_sets, set.toMap());

  @override
  Future<void> deleteSet(String setId) async => _store.softDelete(_sets, (row) => row['id'] == setId);

  @override
  Future<void> deleteWorkout(String workoutId) async {
    _store.softDelete(_sets, (row) => row['workout_id'] == workoutId);
    _store.softDelete(_workouts, (row) => row['id'] == workoutId);
  }
}
