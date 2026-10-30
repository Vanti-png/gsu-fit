import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/body/data/sqlite_body_repository.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';

final bodyRepositoryProvider = Provider<BodyRepository>(
  (ref) => SqliteBodyRepository(ref.watch(appDatabaseProvider)),
);

/// Newest first.
final measurementsProvider = FutureProvider<List<BodyMeasurement>>(
  (ref) => ref.watch(bodyRepositoryProvider).getMeasurements(),
);

/// Newest first.
final photosProvider = FutureProvider<List<ProgressPhoto>>(
  (ref) => ref.watch(bodyRepositoryProvider).getPhotos(),
);

final photoStorageProvider = Provider<PhotoStorage>((ref) => PhotoStorage());

final bodyActionsProvider = Provider<BodyActions>((ref) => BodyActions(ref));

/// Progress photos live only in the app's private documents directory:
/// they are not visible to the gallery, other apps or backups.
class PhotoStorage {
  Future<Directory> _directory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'progress_photos'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> keep(String sourcePath, String id) async {
    final directory = await _directory();
    final extension = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(directory.path, '$id$extension');
    await File(sourcePath).copy(target);
    return target;
  }

  Future<void> remove(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> removeAll() async {
    final directory = await _directory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

class BodyActions {
  BodyActions(this._ref);

  final Ref _ref;

  /// Saves [measurement]; when it is the newest weight entry the profile is
  /// updated too so calorie targets follow the current weight.
  Future<void> saveMeasurement(BodyMeasurement measurement) async {
    await _ref.read(bodyRepositoryProvider).saveMeasurement(measurement);
    _ref.invalidate(measurementsProvider);
    final weight = measurement.weightKg;
    if (weight == null) return;
    final all = await _ref.read(measurementsProvider.future);
    final newest = all.where((m) => m.weightKg != null).firstOrNull;
    final profile = await _ref.read(profileProvider.future);
    if (profile == null || newest?.id != measurement.id) return;
    await _ref.read(profileRepositoryProvider).save(
          profile.copyWith(weightKg: weight, heightCm: measurement.heightCm),
        );
    _ref.invalidate(profileProvider);
  }

  Future<void> deleteMeasurement(String id) async {
    await _ref.read(bodyRepositoryProvider).deleteMeasurement(id);
    _ref.invalidate(measurementsProvider);
  }

  Future<void> addPhoto({required String sourcePath, required String id, required DateTime date}) async {
    final path = await _ref.read(photoStorageProvider).keep(sourcePath, id);
    await _ref.read(bodyRepositoryProvider).savePhoto(
          ProgressPhoto(id: id, date: date, filePath: path),
        );
    _ref.invalidate(photosProvider);
  }

  /// Removes the image file itself, not just the database row.
  Future<void> deletePhoto(ProgressPhoto photo) async {
    await _ref.read(bodyRepositoryProvider).deletePhoto(photo.id);
    await _ref.read(photoStorageProvider).remove(photo.filePath);
    _ref.invalidate(photosProvider);
  }
}
