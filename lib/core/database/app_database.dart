import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:gsu_fit/core/database/migrations.dart';

/// Owns the single on-device SQLite database.
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  static const String fileName = 'gsu_fit.db';
  static const int schemaVersion = 1;

  /// Tables holding user data, in an order that is safe to import.
  /// `settings` is device-local and `progress_photos` points at private
  /// files, so neither is exported or synced.
  static const List<String> dataTables = [
    'profile',
    'exercises',
    'programs',
    'program_days',
    'program_exercises',
    'workouts',
    'workout_sets',
    'cardio_sessions',
    'body_measurements',
    'food_entries',
    'water_entries',
  ];

  static const List<String> allTables = [
    ...dataTables,
    'progress_photos',
    'settings',
  ];

  static Future<AppDatabase> open() async {
    final directory = await getDatabasesPath();
    final db = await openDatabase(
      p.join(directory, fileName),
      version: schemaVersion,
      onCreate: (db, version) => _migrate(db, 0, version),
      onUpgrade: _migrate,
    );
    return AppDatabase(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var version = from + 1; version <= to; version++) {
      final batch = db.batch();
      for (final statement in migrations[version] ?? const <String>[]) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<List<String>> columnsOf(String table, {DatabaseExecutor? executor}) async {
    final rows = await (executor ?? db).rawQuery('PRAGMA table_info($table)');
    return [for (final row in rows) row['name']! as String];
  }
}
