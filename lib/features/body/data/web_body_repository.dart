import 'package:gsu_fit/core/utils/map_read.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';

class WebBodyRepository implements BodyRepository {
  WebBodyRepository(this._store);

  final JsonStore _store;

  static const String _measurements = 'body_measurements';
  static const String _photos = 'progress_photos';

  List<Map<String, Object?>> _newestFirst(String table) => _store.rows(table)
    ..sort((a, b) => (readInt(b['date']) ?? 0).compareTo(readInt(a['date']) ?? 0));

  @override
  Future<List<BodyMeasurement>> getMeasurements() async =>
      _newestFirst(_measurements).map(BodyMeasurement.fromMap).toList();

  @override
  Future<void> saveMeasurement(BodyMeasurement measurement) async =>
      _store.upsert(_measurements, measurement.toMap());

  @override
  Future<void> deleteMeasurement(String id) async =>
      _store.softDelete(_measurements, (row) => row['id'] == id);

  // Progress photos are Android-only (see PhotosTab); these stay for
  // completeness of the interface.
  @override
  Future<List<ProgressPhoto>> getPhotos() async =>
      _newestFirst(_photos).map(ProgressPhoto.fromMap).toList();

  @override
  Future<void> savePhoto(ProgressPhoto photo) async => _store.upsert(_photos, photo.toMap());

  @override
  Future<void> deletePhoto(String id) async => _store.softDelete(_photos, (row) => row['id'] == id);
}
