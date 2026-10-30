import 'package:gsu_fit/core/utils/text.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';

class WebExerciseRepository implements ExerciseRepository {
  WebExerciseRepository(this._store);

  final JsonStore _store;

  static const String _table = 'exercises';

  @override
  Future<List<Exercise>> getAll({bool includeDeleted = false}) async {
    return _store.rows(_table, includeDeleted: includeDeleted).map(Exercise.fromMap).toList()
      ..sort((a, b) => turkishCompare(a.name, b.name));
  }

  @override
  Future<Exercise?> getById(String id) async {
    final row = _store.byId(_table, id);
    return row == null ? null : Exercise.fromMap(row);
  }

  @override
  Future<void> save(Exercise exercise) async => _store.upsert(_table, exercise.toMap());

  @override
  Future<void> delete(String id) async => _store.softDelete(_table, (row) => row['id'] == id);
}
