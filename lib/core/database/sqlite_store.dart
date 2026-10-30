import 'package:sqflite/sqflite.dart';

import 'package:gsu_fit/core/database/app_database.dart';

/// Shared helpers for repositories that keep the sync bookkeeping columns
/// (`created_at`, `updated_at`, `deleted_at`) correct.
abstract class SqliteStore {
  SqliteStore(this.database);

  final AppDatabase database;

  Database get db => database.db;

  int get nowMillis => DateTime.now().millisecondsSinceEpoch;

  /// Inserts or replaces [row]; stamps `updated_at` and keeps `created_at`.
  Future<void> upsertRow(
    String table,
    Map<String, Object?> row, {
    DatabaseExecutor? executor,
  }) async {
    final now = nowMillis;
    final data = Map<String, Object?>.of(row)
      ..['updated_at'] = now
      ..['deleted_at'] = null;
    data['created_at'] ??= now;
    await (executor ?? db).insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Marks rows as deleted instead of removing them (see migrations.dart).
  Future<void> softDelete(
    String table, {
    required String where,
    required List<Object?> whereArgs,
    DatabaseExecutor? executor,
  }) async {
    final now = nowMillis;
    await (executor ?? db).update(
      table,
      {'deleted_at': now, 'updated_at': now},
      where: '($where) AND deleted_at IS NULL',
      whereArgs: whereArgs,
    );
  }

  Future<List<Map<String, Object?>>> queryActive(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    DatabaseExecutor? executor,
  }) {
    return (executor ?? db).query(
      table,
      where: where == null ? 'deleted_at IS NULL' : '($where) AND deleted_at IS NULL',
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }
}
