import 'package:gsu_fit/core/database/sqlite_store.dart';
import 'package:gsu_fit/core/utils/text.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';

class SqliteExerciseRepository extends SqliteStore implements ExerciseRepository {
  SqliteExerciseRepository(super.database);

  static const String _table = 'exercises';

  @override
  Future<List<Exercise>> getAll({bool includeDeleted = false}) async {
    final rows = includeDeleted ? await db.query(_table) : await queryActive(_table);
    return rows.map(Exercise.fromMap).toList()
      ..sort((a, b) => turkishCompare(a.name, b.name));
  }

  @override
  Future<Exercise?> getById(String id) async {
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Exercise.fromMap(rows.first);
  }

  @override
  Future<void> save(Exercise exercise) => upsertRow(_table, exercise.toMap());

  @override
  Future<void> delete(String id) => softDelete(_table, where: 'id = ?', whereArgs: [id]);
}
