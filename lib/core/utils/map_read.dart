/// Tolerant readers for database rows and imported JSON/CSV values.
///
/// SQLite returns ints for INTEGER columns and doubles for REAL columns,
/// while imported files may contain strings; these helpers accept all of them.
library;

double? readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

int? readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.round();
  return null;
}

String? readString(Object? value) => value?.toString();

bool readBool(Object? value) =>
    value == true || value == 1 || value == '1' || value == 'true';

DateTime? readDate(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  final millis = readInt(value);
  return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
}

T readEnum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Splits a stored list (e.g. "chest,triceps") into its non-empty parts.
List<String> readList(Object? value, String separator) {
  final text = readString(value);
  if (text == null || text.isEmpty) return const [];
  return text.split(separator).where((part) => part.isNotEmpty).toList();
}

List<T> readEnumList<T extends Enum>(List<T> values, Object? raw) {
  final result = <T>[];
  for (final name in readList(raw, ',')) {
    for (final value in values) {
      if (value.name == name) {
        result.add(value);
        break;
      }
    }
  }
  return result;
}
