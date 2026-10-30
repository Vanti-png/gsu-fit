import 'package:gsu_fit/core/database/sqlite_store.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';

class SqliteBodyRepository extends SqliteStore implements BodyRepository {
  SqliteBodyRepository(super.database);

  static const String _measurements = 'body_measurements';
  static const String _photos = 'progress_photos';

  @override
  Future<List<BodyMeasurement>> getMeasurements() async {
    final rows = await queryActive(_measurements, orderBy: 'date DESC');
    return rows.map(BodyMeasurement.fromMap).toList();
  }

  @override
  Future<void> saveMeasurement(BodyMeasurement measurement) =>
      upsertRow(_measurements, measurement.toMap());

  @override
  Future<void> deleteMeasurement(String id) =>
      softDelete(_measurements, where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<ProgressPhoto>> getPhotos() async {
    final rows = await queryActive(_photos, orderBy: 'date DESC');
    return rows.map(ProgressPhoto.fromMap).toList();
  }

  @override
  Future<void> savePhoto(ProgressPhoto photo) => upsertRow(_photos, photo.toMap());

  @override
  Future<void> deletePhoto(String id) => softDelete(_photos, where: 'id = ?', whereArgs: [id]);
}
