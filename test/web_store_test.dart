import 'package:flutter_test/flutter_test.dart';

import 'package:gsu_fit/core/database/migrations.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/features/body/data/web_body_repository.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';
import 'package:gsu_fit/features/data_transfer/data/data_transfer_service.dart';
import 'package:gsu_fit/features/data_transfer/data/table_access.dart';
import 'package:gsu_fit/features/programs/data/web_program_repository.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/settings/data/web_settings_repository.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';
import 'package:gsu_fit/features/workout/data/web_workout_repository.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';

JsonStore newStore() => JsonStore(MemoryPersistence());

WorkoutSet doneSet(String id, String workoutId, int index) => WorkoutSet(
      id: id,
      workoutId: workoutId,
      exerciseId: 'squat',
      exerciseOrder: 0,
      setIndex: index,
      reps: 5,
      weightKg: 100,
      completed: true,
    );

Program program(String id) => Program(
      id: id,
      name: id,
      split: ProgramSplit.custom,
      startDate: DateTime(2026, 10, 1),
      days: [
        ProgramDay(
          id: '$id-d',
          programId: id,
          name: 'Gün',
          position: 0,
          exercises: [
            ProgramExercise(
              id: '$id-e',
              dayId: '$id-d',
              exerciseId: 'squat',
              position: 0,
              sets: 3,
              minReps: 8,
              maxReps: 12,
              restSeconds: 90,
            ),
          ],
        ),
      ],
    );

void main() {
  test('schemaColumns reads every table from the migrations', () {
    final schema = schemaColumns();
    expect(
      schema.keys,
      containsAll([
        'profile',
        'exercises',
        'programs',
        'program_days',
        'program_exercises',
        'workouts',
        'workout_sets',
        'cardio_sessions',
        'body_measurements',
        'progress_photos',
        'food_entries',
        'water_entries',
        'settings',
      ]),
    );
    expect(
      schema['workout_sets'],
      containsAll(['id', 'workout_id', 'reps', 'weight_kg', 'created_at', 'updated_at', 'deleted_at']),
    );
    expect(schema['settings'], ['key', 'value']);
  });

  group('JsonStore', () {
    test('persists rows across a reload', () {
      final persistence = MemoryPersistence();
      JsonStore(persistence).upsert('t', {'id': 'a', 'n': 1});
      final reloaded = JsonStore(persistence).rows('t').single;
      expect(reloaded['n'], 1);
      expect(reloaded['created_at'], isNotNull);
    });

    test('upsert replaces by id and keeps created_at', () {
      final store = newStore()..upsert('t', {'id': 'a', 'n': 1});
      final created = store.rows('t').single['created_at'];
      store.upsert('t', {...store.rows('t').single, 'n': 2});
      expect(store.rows('t'), hasLength(1));
      expect(store.rows('t').single['n'], 2);
      expect(store.rows('t').single['created_at'], created);
    });

    test('soft delete hides rows but keeps them for export', () {
      final store = newStore()
        ..upsertAll('t', [
          {'id': 'a'},
          {'id': 'b'},
        ]);
      expect(store.softDelete('t', (row) => row['id'] == 'a'), 1);
      expect(store.rows('t').map((row) => row['id']), ['b']);
      expect(store.rows('t', includeDeleted: true), hasLength(2));
      expect(store.byId('t', 'a')?['deleted_at'], isNotNull);
    });

    test('returned rows are copies', () {
      final store = newStore()..upsert('t', {'id': 'a', 'n': 1});
      store.rows('t').single['n'] = 99;
      expect(store.rows('t').single['n'], 1);
    });

    test('clear removes tables and values', () {
      final persistence = MemoryPersistence();
      JsonStore(persistence)
        ..upsert('t', {'id': 'a'})
        ..setValue('k', 'v')
        ..clear(['t'], values: ['k']);
      final reloaded = JsonStore(persistence);
      expect(reloaded.rows('t'), isEmpty);
      expect(reloaded.value('k'), isNull);
    });
  });

  test('WebWorkoutRepository separates open and finished workouts', () async {
    final repository = WebWorkoutRepository(newStore());
    final start = DateTime(2026, 10, 30, 18);
    await repository.saveFull(Workout(
      id: 'done',
      name: 'A',
      startedAt: start,
      endedAt: start.add(const Duration(hours: 1)),
      durationSeconds: 3600,
      sets: [doneSet('s2', 'done', 1), doneSet('s1', 'done', 0)],
    ));
    await repository.saveFull(Workout(id: 'open', name: 'B', startedAt: start.add(const Duration(days: 1))));

    final finished = await repository.getFinished();
    expect(finished.single.id, 'done');
    expect(finished.single.sets.map((s) => s.id), ['s1', 's2']);
    expect((await repository.getUnfinished())?.id, 'open');

    await repository.deleteWorkout('done');
    expect(await repository.getFinished(), isEmpty);
  });

  test('WebProgramRepository keeps a single active program', () async {
    final repository = WebProgramRepository(newStore());
    await repository.saveFull(program('a'));
    await repository.saveFull(program('b'));
    await repository.setActive('a');
    await repository.setActive('b');

    final all = await repository.getAll();
    expect(all.where((p) => p.isActive).map((p) => p.id), ['b']);
    expect(all.first.id, 'b');
    expect(all.first.days.single.exercises.single.exerciseId, 'squat');

    await repository.deleteProgram('a');
    expect((await repository.getAll()).map((p) => p.id), ['b']);
  });

  test('settings round-trip through the web store', () async {
    final repository = WebSettingsRepository(newStore());
    expect((await repository.load()).weightUnit, WeightUnit.kg);
    await repository.save(const AppSettings(weightUnit: WeightUnit.lb));
    expect((await repository.load()).weightUnit, WeightUnit.lb);
  });

  group('backups on the web store', () {
    test('a JSON backup imports into another store', () async {
      final source = newStore();
      await WebWorkoutRepository(source).saveFull(Workout(
        id: 'w',
        name: 'A',
        startedAt: DateTime(2026, 10, 30),
        endedAt: DateTime(2026, 10, 30, 1),
        sets: [doneSet('s', 'w', 0)],
      ));
      final json = await DataTransferService(JsonTableAccess(source)).exportJson();

      final target = newStore();
      final report = await DataTransferService(JsonTableAccess(target)).importJson(json);
      expect(report.imported, 2);
      expect(report.skipped, 0);
      final restored = await WebWorkoutRepository(target).getFinished();
      expect(restored.single.sets.single.weightKg, 100);
    });

    test('a CSV table round-trips, including dates and decimals', () async {
      final source = newStore();
      await WebBodyRepository(source).saveMeasurement(
        BodyMeasurement(id: 'm1', date: DateTime(2026, 10, 1), weightKg: 80.5, waistCm: 85),
      );
      final csv = await DataTransferService(JsonTableAccess(source)).exportCsv('body_measurements');

      final target = newStore();
      final report =
          await DataTransferService(JsonTableAccess(target)).importCsv('body_measurements', csv);
      expect(report.imported, 1);
      final restored = (await WebBodyRepository(target).getMeasurements()).single;
      expect(restored.weightKg, 80.5);
      expect(restored.waistCm, 85);
      expect(restored.heightCm, isNull);
      expect(restored.date, DateTime(2026, 10, 1));
    });

    test('files from other apps are rejected', () async {
      final service = DataTransferService(JsonTableAccess(newStore()));
      await expectLater(service.importJson('{"app": "other"}'), throwsA(isA<ImportFormatException>()));
      await expectLater(service.importJson('not json'), throwsA(isA<ImportFormatException>()));
    });
  });
}
