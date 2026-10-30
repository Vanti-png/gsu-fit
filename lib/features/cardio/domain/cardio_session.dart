import 'package:gsu_fit/core/utils/map_read.dart';

enum CardioType { running, walking, cycling, swimming, rowing, elliptical, jumpRope, hiking, other }

class CardioSession {
  const CardioSession({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.durationSeconds,
    this.distanceKm,
    this.calories = 0,
    this.notes = '',
    this.createdAt,
  });

  final String id;
  final CardioType type;
  final DateTime startedAt;
  final int durationSeconds;
  final double? distanceKm;
  final double calories;
  final String notes;
  final DateTime? createdAt;

  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'started_at': startedAt.millisecondsSinceEpoch,
        'duration_seconds': durationSeconds,
        'distance_km': distanceKm,
        'calories': calories,
        'notes': notes,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory CardioSession.fromMap(Map<String, Object?> map) => CardioSession(
        id: map['id']! as String,
        type: readEnum(CardioType.values, map['type'], CardioType.other),
        startedAt: readDate(map['started_at']) ?? DateTime.now(),
        durationSeconds: readInt(map['duration_seconds']) ?? 0,
        distanceKm: readDouble(map['distance_km']),
        calories: readDouble(map['calories']) ?? 0,
        notes: readString(map['notes']) ?? '',
        createdAt: readDate(map['created_at']),
      );
}

abstract interface class CardioRepository {
  /// Newest first.
  Future<List<CardioSession>> getAll();

  Future<void> save(CardioSession session);

  Future<void> delete(String id);
}
