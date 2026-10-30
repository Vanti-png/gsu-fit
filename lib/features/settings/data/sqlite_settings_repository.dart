import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:gsu_fit/core/database/app_database.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';

/// Device-local key/value store; settings are not part of exports or sync.
class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._database);

  final AppDatabase _database;

  static const String _table = 'settings';
  static const String _settingsKey = 'app_settings';

  @override
  Future<AppSettings> load() async {
    final raw = await getValue(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppSettings.fromJson(decoded);
    } on FormatException {
      // Fall through to defaults; a corrupt value should not block startup.
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) =>
      setValue(_settingsKey, jsonEncode(settings.toJson()));

  @override
  Future<String?> getValue(String key) async {
    final rows = await _database.db.query(
      _table,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setValue(String key, String value) async {
    await _database.db.insert(
      _table,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
