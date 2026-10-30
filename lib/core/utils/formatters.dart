import 'package:intl/intl.dart';

import 'package:gsu_fit/core/utils/units.dart';

final NumberFormat _integer = NumberFormat('#,##0', 'tr');
final NumberFormat _oneDecimal = NumberFormat('#,##0.#', 'tr');
final NumberFormat _twoDecimals = NumberFormat('#,##0.##', 'tr');
final NumberFormat _input = NumberFormat('0.##', 'tr');

/// Formats with Turkish separators: 1.234,5
String formatNumber(num value, {int decimals = 1}) => switch (decimals) {
      0 => _integer.format(value),
      1 => _oneDecimal.format(value),
      _ => _twoDecimals.format(value),
    };

/// Value suitable for pre-filling a text field (no grouping separator).
String formatInputNumber(num value) => _input.format(value);

String formatWeight(double kg, WeightUnit unit, {int decimals = 1}) =>
    '${formatNumber(unit.fromKg(kg), decimals: decimals)} ${unit.symbol}';

String formatDistance(double km) => '${formatNumber(km, decimals: 2)} km';

/// Accepts both "62,5" and "62.5".
double? parseDecimal(String? text) {
  if (text == null) return null;
  final normalized = text.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

int? parseInt(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  return int.tryParse(trimmed) ?? parseDecimal(trimmed)?.round();
}

String formatDate(DateTime date) => DateFormat('d MMMM y', 'tr').format(date);

String formatDateShort(DateTime date) => DateFormat('d MMM', 'tr').format(date);

String formatDateWithWeekday(DateTime date) =>
    DateFormat('d MMMM EEEE', 'tr').format(date);

String formatTime(DateTime date) => DateFormat.Hm('tr').format(date);

String formatDateTime(DateTime date) => '${formatDate(date)} ${formatTime(date)}';
