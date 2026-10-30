import 'package:gsu_fit/core/utils/map_read.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';

class WebProfileRepository implements ProfileRepository {
  WebProfileRepository(this._store);

  final JsonStore _store;

  static const String _table = 'profile';

  @override
  Future<UserProfile?> get() async {
    final rows = _store.rows(_table)
      ..sort((a, b) => (readInt(b['updated_at']) ?? 0).compareTo(readInt(a['updated_at']) ?? 0));
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  @override
  Future<void> save(UserProfile profile) async => _store.upsert(_table, profile.toMap());
}
