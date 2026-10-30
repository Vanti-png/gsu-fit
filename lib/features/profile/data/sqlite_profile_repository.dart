import 'package:gsu_fit/core/database/sqlite_store.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';

class SqliteProfileRepository extends SqliteStore implements ProfileRepository {
  SqliteProfileRepository(super.database);

  static const String _table = 'profile';

  @override
  Future<UserProfile?> get() async {
    final rows = await queryActive(_table, orderBy: 'updated_at DESC', limit: 1);
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  @override
  Future<void> save(UserProfile profile) => upsertRow(_table, profile.toMap());
}
