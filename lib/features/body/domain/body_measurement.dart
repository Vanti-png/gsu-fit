import 'package:gsu_fit/core/utils/map_read.dart';

/// Fields that can be charted over time.
enum MeasurementField { weight, bodyFat, chest, waist, arm, leg }

class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.date,
    this.weightKg,
    this.heightCm,
    this.bodyFatPercent,
    this.chestCm,
    this.waistCm,
    this.armCm,
    this.legCm,
    this.notes = '',
    this.createdAt,
  });

  final String id;
  final DateTime date;
  final double? weightKg;
  final double? heightCm;
  final double? bodyFatPercent;
  final double? chestCm;
  final double? waistCm;
  final double? armCm;
  final double? legCm;
  final String notes;
  final DateTime? createdAt;

  double? valueOf(MeasurementField field) => switch (field) {
        MeasurementField.weight => weightKg,
        MeasurementField.bodyFat => bodyFatPercent,
        MeasurementField.chest => chestCm,
        MeasurementField.waist => waistCm,
        MeasurementField.arm => armCm,
        MeasurementField.leg => legCm,
      };

  /// Body-mass index, using [fallbackHeightCm] when this entry has no height.
  double? bmi({double? fallbackHeightCm}) {
    final height = heightCm ?? fallbackHeightCm;
    final weight = weightKg;
    if (height == null || height <= 0 || weight == null) return null;
    final meters = height / 100;
    return weight / (meters * meters);
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'body_fat_percent': bodyFatPercent,
        'chest_cm': chestCm,
        'waist_cm': waistCm,
        'arm_cm': armCm,
        'leg_cm': legCm,
        'notes': notes,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory BodyMeasurement.fromMap(Map<String, Object?> map) => BodyMeasurement(
        id: map['id']! as String,
        date: readDate(map['date']) ?? DateTime.now(),
        weightKg: readDouble(map['weight_kg']),
        heightCm: readDouble(map['height_cm']),
        bodyFatPercent: readDouble(map['body_fat_percent']),
        chestCm: readDouble(map['chest_cm']),
        waistCm: readDouble(map['waist_cm']),
        armCm: readDouble(map['arm_cm']),
        legCm: readDouble(map['leg_cm']),
        notes: readString(map['notes']) ?? '',
        createdAt: readDate(map['created_at']),
      );
}

class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.date,
    required this.filePath,
    this.note = '',
    this.createdAt,
  });

  final String id;
  final DateTime date;

  /// Absolute path inside the app's private documents directory.
  final String filePath;
  final String note;
  final DateTime? createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'file_path': filePath,
        'note': note,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory ProgressPhoto.fromMap(Map<String, Object?> map) => ProgressPhoto(
        id: map['id']! as String,
        date: readDate(map['date']) ?? DateTime.now(),
        filePath: readString(map['file_path']) ?? '',
        note: readString(map['note']) ?? '',
        createdAt: readDate(map['created_at']),
      );
}

abstract interface class BodyRepository {
  /// Newest first.
  Future<List<BodyMeasurement>> getMeasurements();

  Future<void> saveMeasurement(BodyMeasurement measurement);

  Future<void> deleteMeasurement(String id);

  /// Newest first.
  Future<List<ProgressPhoto>> getPhotos();

  Future<void> savePhoto(ProgressPhoto photo);

  Future<void> deletePhoto(String id);
}
