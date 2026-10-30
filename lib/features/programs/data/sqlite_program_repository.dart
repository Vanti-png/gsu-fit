import 'package:gsu_fit/core/database/sqlite_store.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';

class SqliteProgramRepository extends SqliteStore implements ProgramRepository {
  SqliteProgramRepository(super.database);

  static const String _programs = 'programs';
  static const String _days = 'program_days';
  static const String _items = 'program_exercises';

  @override
  Future<List<Program>> getAll() async {
    final programRows = await queryActive(_programs, orderBy: 'is_active DESC, created_at DESC');
    if (programRows.isEmpty) return const [];
    final dayRows = await queryActive(_days, orderBy: 'position');
    final itemRows = await queryActive(_items, orderBy: 'position');

    final itemsByDay = <String, List<ProgramExercise>>{};
    for (final row in itemRows) {
      final item = ProgramExercise.fromMap(row);
      itemsByDay.putIfAbsent(item.dayId, () => []).add(item);
    }
    final daysByProgram = <String, List<ProgramDay>>{};
    for (final row in dayRows) {
      final day = ProgramDay.fromMap(row, exercises: itemsByDay[row['id']] ?? const []);
      daysByProgram.putIfAbsent(day.programId, () => []).add(day);
    }
    return [
      for (final row in programRows)
        Program.fromMap(row, days: daysByProgram[row['id']] ?? const []),
    ];
  }

  @override
  Future<void> saveFull(Program program) {
    return db.transaction((txn) async {
      await upsertRow(_programs, program.toMap(), executor: txn);
      for (final day in program.days) {
        await upsertRow(_days, day.toMap(), executor: txn);
        for (final item in day.exercises) {
          await upsertRow(_items, item.toMap(), executor: txn);
        }
      }
    });
  }

  @override
  Future<void> saveProgram(Program program) => upsertRow(_programs, program.toMap());

  @override
  Future<void> setActive(String programId) {
    return db.transaction((txn) async {
      final now = nowMillis;
      await txn.update(
        _programs,
        {'is_active': 0, 'updated_at': now},
        where: 'is_active = 1 AND id != ?',
        whereArgs: [programId],
      );
      await txn.update(
        _programs,
        {'is_active': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [programId],
      );
    });
  }

  @override
  Future<void> deleteProgram(String programId) {
    return db.transaction((txn) async {
      await softDelete(
        _items,
        where: 'day_id IN (SELECT id FROM $_days WHERE program_id = ?)',
        whereArgs: [programId],
        executor: txn,
      );
      await softDelete(_days, where: 'program_id = ?', whereArgs: [programId], executor: txn);
      await softDelete(_programs, where: 'id = ?', whereArgs: [programId], executor: txn);
    });
  }

  @override
  Future<void> saveDay(ProgramDay day) => upsertRow(_days, day.toMap());

  @override
  Future<void> deleteDay(String dayId) {
    return db.transaction((txn) async {
      await softDelete(_items, where: 'day_id = ?', whereArgs: [dayId], executor: txn);
      await softDelete(_days, where: 'id = ?', whereArgs: [dayId], executor: txn);
    });
  }

  @override
  Future<void> saveProgramExercise(ProgramExercise exercise) =>
      upsertRow(_items, exercise.toMap());

  @override
  Future<void> saveProgramExercises(List<ProgramExercise> exercises) {
    return db.transaction((txn) async {
      for (final item in exercises) {
        await upsertRow(_items, item.toMap(), executor: txn);
      }
    });
  }

  @override
  Future<void> deleteProgramExercise(String id) =>
      softDelete(_items, where: 'id = ?', whereArgs: [id]);
}
