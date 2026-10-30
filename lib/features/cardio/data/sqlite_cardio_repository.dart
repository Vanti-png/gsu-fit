import 'package:gsu_fit/core/database/sqlite_store.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';

class SqliteCardioRepository extends SqliteStore implements CardioRepository {
  SqliteCardioRepository(super.database);

  static const String _table = 'cardio_sessions';

  @override
  Future<List<CardioSession>> getAll() async {
    final rows = await queryActive(_table, orderBy: 'started_at DESC');
    return rows.map(CardioSession.fromMap).toList();
  }

  @override
  Future<void> save(CardioSession session) => upsertRow(_table, session.toMap());

  @override
  Future<void> delete(String id) => softDelete(_table, where: 'id = ?', whereArgs: [id]);
}
