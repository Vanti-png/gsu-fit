import 'package:gsu_fit/core/utils/map_read.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';

class WebCardioRepository implements CardioRepository {
  WebCardioRepository(this._store);

  final JsonStore _store;

  static const String _table = 'cardio_sessions';

  @override
  Future<List<CardioSession>> getAll() async {
    final rows = _store.rows(_table)
      ..sort((a, b) => (readInt(b['started_at']) ?? 0).compareTo(readInt(a['started_at']) ?? 0));
    return rows.map(CardioSession.fromMap).toList();
  }

  @override
  Future<void> save(CardioSession session) async => _store.upsert(_table, session.toMap());

  @override
  Future<void> delete(String id) async => _store.softDelete(_table, (row) => row['id'] == id);
}
