import 'package:sqflite/sqflite.dart';

import 'package:gsu_fit/core/database/app_database.dart';
import 'package:gsu_fit/core/database/migrations.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';

/// Raw table access for export/import, implemented for SQLite (Android)
/// and the browser store (web).
abstract interface class TableAccess {
  Future<List<String>> columnsOf(String table);

  Future<List<Map<String, Object?>>> rows(String table, {required bool includeDeleted});

  /// Inserts or replaces rows by id and returns how many were stored.
  Future<int> putRows(String table, List<Map<String, Object?>> rows);

  /// Removes every row of [tables] and all device-local values.
  Future<void> wipe(List<String> tables);
}

class SqliteTableAccess implements TableAccess {
  SqliteTableAccess(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  @override
  Future<List<String>> columnsOf(String table) => _database.columnsOf(table);

  @override
  Future<List<Map<String, Object?>>> rows(String table, {required bool includeDeleted}) =>
      includeDeleted ? _db.query(table) : _db.query(table, where: 'deleted_at IS NULL');

  @override
  Future<int> putRows(String table, List<Map<String, Object?>> rows) async {
    var stored = 0;
    await _db.transaction((txn) async {
      for (final row in rows) {
        try {
          await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
          stored++;
        } on DatabaseException {
          // A row that breaks a constraint is skipped, the rest still import.
        }
      }
    });
    return stored;
  }

  @override
  Future<void> wipe(List<String> tables) async {
    await _db.transaction((txn) async {
      for (final table in tables) {
        await txn.delete(table);
      }
    });
  }
}

class JsonTableAccess implements TableAccess {
  JsonTableAccess(this._store);

  final JsonStore _store;

  static final Map<String, List<String>> _schema = schemaColumns();

  /// Values kept outside the tables (see WebSettingsRepository, SeedService).
  static const List<String> _values = ['app_settings', 'seed_version'];

  @override
  Future<List<String>> columnsOf(String table) async => _schema[table] ?? const [];

  @override
  Future<List<Map<String, Object?>>> rows(String table, {required bool includeDeleted}) async =>
      _store.rows(table, includeDeleted: includeDeleted);

  @override
  Future<int> putRows(String table, List<Map<String, Object?>> rows) async {
    final required = {'id', 'created_at', 'updated_at'};
    final valid = [
      for (final row in rows)
        if (required.every((c) => row[c] != null)) row,
    ];
    _store.upsertAll(table, valid, stamp: false);
    return valid.length;
  }

  @override
  Future<void> wipe(List<String> tables) async => _store.clear(tables, values: _values);
}
