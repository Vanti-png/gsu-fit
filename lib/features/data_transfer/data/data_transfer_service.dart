import 'dart:convert';

import 'package:gsu_fit/core/database/app_database.dart';
import 'package:gsu_fit/features/data_transfer/data/table_access.dart';
import 'package:gsu_fit/features/data_transfer/domain/csv_codec.dart';

class ImportReport {
  const ImportReport({required this.imported, required this.skipped});

  final int imported;
  final int skipped;
}

/// Thrown for files that are not GSU Fit exports.
class ImportFormatException implements Exception {
  const ImportFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'ImportFormatException($reason)';
}

/// JSON backups (all tables) and CSV exports (one table each).
///
/// Imports merge by primary key: a row with an existing id replaces it,
/// new ids are added. Nothing is deleted, so importing twice is harmless.
/// The same files work on Android and on the web, so a backup taken in the
/// browser can be imported into the app later.
class DataTransferService {
  DataTransferService(this._access);

  final TableAccess _access;

  static const String appTag = 'gsu_fit';
  static const int formatVersion = 1;

  /// Tables offered for CSV export/import.
  static const List<String> csvTables = [
    'workouts',
    'workout_sets',
    'cardio_sessions',
    'body_measurements',
    'food_entries',
    'water_entries',
    'exercises',
    'programs',
    'program_days',
    'program_exercises',
    'profile',
  ];

  Future<String> exportJson() async {
    final tables = <String, Object?>{};
    for (final table in AppDatabase.dataTables) {
      // Soft-deleted rows are included so a restore (or a future sync)
      // also knows what was removed.
      tables[table] = await _access.rows(table, includeDeleted: true);
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': appTag,
      'formatVersion': formatVersion,
      'schemaVersion': AppDatabase.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    });
  }

  Future<ImportReport> importJson(String content) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw const ImportFormatException('invalid_json');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != appTag) {
      throw const ImportFormatException('not_gsu_fit');
    }
    final schema = decoded['schemaVersion'];
    if (schema is int && schema > AppDatabase.schemaVersion) {
      throw const ImportFormatException('newer_version');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const ImportFormatException('no_tables');
    }

    var imported = 0;
    var skipped = 0;
    for (final table in AppDatabase.dataTables) {
      final rows = tables[table];
      if (rows is! List) continue;
      final columns = (await _access.columnsOf(table)).toSet();
      final valid = <Map<String, Object?>>[];
      for (final raw in rows) {
        final row = raw is Map ? _sanitize(Map<String, Object?>.from(raw), columns) : null;
        if (row == null) {
          skipped++;
        } else {
          valid.add(row);
        }
      }
      final stored = await _access.putRows(table, valid);
      imported += stored;
      skipped += valid.length - stored;
    }
    return ImportReport(imported: imported, skipped: skipped);
  }

  Future<String> exportCsv(String table) async {
    final columns = await _access.columnsOf(table);
    final rows = await _access.rows(table, includeDeleted: false);
    final values = [
      for (final row in rows) [for (final column in columns) _toCsv(column, row[column])],
    ];
    return CsvCodec.bom + const CsvCodec().encode(columns, values);
  }

  Future<ImportReport> importCsv(String table, String content) async {
    final rows = const CsvCodec().decodeMaps(content);
    if (rows.isEmpty) return const ImportReport(imported: 0, skipped: 0);
    if (!rows.first.containsKey('id')) {
      throw const ImportFormatException('missing_id');
    }
    final columns = (await _access.columnsOf(table)).toSet();
    final valid = <Map<String, Object?>>[];
    var skipped = 0;
    for (final raw in rows) {
      final values = <String, Object?>{};
      raw.forEach((column, value) {
        // Empty cells are left out so column defaults apply.
        if (value.isEmpty) return;
        values[column] = _fromCsv(column, value);
      });
      final row = _sanitize(values, columns);
      if (row == null) {
        skipped++;
      } else {
        valid.add(row);
      }
    }
    final stored = await _access.putRows(table, valid);
    return ImportReport(imported: stored, skipped: skipped + valid.length - stored);
  }

  /// Guesses the table from a file name such as
  /// "gsu_fit_body_measurements_2026-10-30.csv".
  static String? tableFromFileName(String fileName) {
    final name = fileName.toLowerCase();
    final candidates = [...csvTables]..sort((a, b) => b.length.compareTo(a.length));
    for (final table in candidates) {
      if (name.contains(table)) return table;
    }
    return null;
  }

  static bool _isDateColumn(String column) =>
      column.endsWith('_at') || column == 'date' || column == 'start_date';

  Object? _toCsv(String column, Object? value) {
    if (value is int && _isDateColumn(column)) {
      return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
    }
    return value;
  }

  Object? _fromCsv(String column, String value) {
    if (_isDateColumn(column)) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    // Numbers stay text here: SQLite's column affinity converts them, and
    // the models' readers accept numeric strings on the web.
    return value;
  }

  Map<String, Object?>? _sanitize(Map<String, Object?> raw, Set<String> columns) {
    final row = <String, Object?>{
      for (final entry in raw.entries)
        if (columns.contains(entry.key)) entry.key: entry.value,
    };
    final id = row['id'];
    if (id == null || id.toString().isEmpty) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    row['created_at'] ??= now;
    row['updated_at'] ??= now;
    return row;
  }

  /// Removes every row of every table; used by "delete all data".
  Future<void> wipe() => _access.wipe(AppDatabase.allTables);
}
