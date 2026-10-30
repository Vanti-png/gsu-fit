import 'dart:convert';

/// Where [JsonStore] keeps its data: the browser's localStorage on the web,
/// memory in tests.
abstract interface class KeyValuePersistence {
  String? read(String key);

  void write(String key, String value);

  void remove(String key);
}

class MemoryPersistence implements KeyValuePersistence {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);
}

/// Table storage for the web build, where SQLite is not available.
///
/// Rows have the same columns as the SQLite schema (the models' toMap and
/// fromMap) and the same created/updated/deleted bookkeeping, so exports,
/// imports and a future sync see the same data on both platforms. Each
/// table is kept in memory and written back as one JSON value on change.
class JsonStore {
  JsonStore(this._persistence);

  final KeyValuePersistence _persistence;
  final Map<String, List<Map<String, Object?>>> _tables = {};

  static const String _tablePrefix = 'gsu_fit.table.';
  static const String _valuePrefix = 'gsu_fit.value.';

  int get _now => DateTime.now().millisecondsSinceEpoch;

  List<Map<String, Object?>> _table(String name) => _tables.putIfAbsent(name, () {
        final raw = _persistence.read('$_tablePrefix$name');
        if (raw == null) return <Map<String, Object?>>[];
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! List) return <Map<String, Object?>>[];
          return [
            for (final row in decoded)
              if (row is Map) Map<String, Object?>.from(row),
          ];
        } on FormatException {
          return <Map<String, Object?>>[];
        }
      });

  void _save(String name) =>
      _persistence.write('$_tablePrefix$name', jsonEncode(_tables[name] ?? const []));

  /// Copies of the rows; soft-deleted rows only with [includeDeleted].
  List<Map<String, Object?>> rows(String table, {bool includeDeleted = false}) => [
        for (final row in _table(table))
          if (includeDeleted || row['deleted_at'] == null) Map<String, Object?>.of(row),
      ];

  /// Any row with this id, deleted or not.
  Map<String, Object?>? byId(String table, String id) {
    for (final row in _table(table)) {
      if (row['id'] == id) return Map<String, Object?>.of(row);
    }
    return null;
  }

  void upsert(String table, Map<String, Object?> row) => upsertAll(table, [row]);

  /// Inserts or replaces rows by id. With [stamp] (normal saves) the row is
  /// marked as changed now and not deleted; imports pass false to keep the
  /// timestamps from the file.
  void upsertAll(String table, Iterable<Map<String, Object?>> rows, {bool stamp = true}) {
    final list = _table(table);
    final now = _now;
    for (final row in rows) {
      final data = Map<String, Object?>.of(row);
      if (stamp) {
        data['updated_at'] = now;
        data['deleted_at'] = null;
      }
      data['created_at'] ??= now;
      data['updated_at'] ??= now;
      final index = list.indexWhere((existing) => existing['id'] == data['id']);
      if (index >= 0) {
        list[index] = data;
      } else {
        list.add(data);
      }
    }
    _save(table);
  }

  /// Applies [change] to every live row; rows for which it returns true are
  /// stamped as updated.
  void modify(String table, bool Function(Map<String, Object?> row) change) {
    final now = _now;
    var changed = false;
    for (final row in _table(table)) {
      if (row['deleted_at'] != null) continue;
      if (change(row)) {
        row['updated_at'] = now;
        changed = true;
      }
    }
    if (changed) _save(table);
  }

  /// Marks matching live rows as deleted; returns how many.
  int softDelete(String table, bool Function(Map<String, Object?> row) test) {
    final now = _now;
    var count = 0;
    for (final row in _table(table)) {
      if (row['deleted_at'] == null && test(row)) {
        row['deleted_at'] = now;
        row['updated_at'] = now;
        count++;
      }
    }
    if (count > 0) _save(table);
    return count;
  }

  /// Removes tables and values completely ("delete all data").
  void clear(Iterable<String> tables, {Iterable<String> values = const []}) {
    for (final table in tables) {
      _tables[table] = <Map<String, Object?>>[];
      _persistence.remove('$_tablePrefix$table');
    }
    for (final key in values) {
      _persistence.remove('$_valuePrefix$key');
    }
  }

  String? value(String key) => _persistence.read('$_valuePrefix$key');

  void setValue(String key, String value) => _persistence.write('$_valuePrefix$key', value);
}
