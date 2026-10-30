DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Monday of the week [date] falls in, at midnight.
DateTime startOfWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _two(int value) => value.toString().padLeft(2, '0');

/// Stable per-day key ("2026-10-30") used by the nutrition tables.
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

DateTime parseDayKey(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// "05:07" or "1:05:07"; used by the workout clock and rest timer.
String formatClock(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);
  return hours > 0
      ? '$hours:${_two(minutes)}:${_two(seconds)}'
      : '${_two(minutes)}:${_two(seconds)}';
}

String formatMinutesOfDay(int minutes) =>
    '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
