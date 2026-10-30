import 'package:gsu_fit/core/utils/map_read.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';

class WebProgramRepository implements ProgramRepository {
  WebProgramRepository(this._store);

  final JsonStore _store;

  static const String _programs = 'programs';
  static const String _days = 'program_days';
  static const String _items = 'program_exercises';

  int _position(Map<String, Object?> row) => readInt(row['position']) ?? 0;

  @override
  Future<List<Program>> getAll() async {
    final programRows = _store.rows(_programs)
      ..sort((a, b) {
        final active = (readInt(b['is_active']) ?? 0).compareTo(readInt(a['is_active']) ?? 0);
        if (active != 0) return active;
        return (readInt(b['created_at']) ?? 0).compareTo(readInt(a['created_at']) ?? 0);
      });
    if (programRows.isEmpty) return const [];
    final dayRows = _store.rows(_days)..sort((a, b) => _position(a).compareTo(_position(b)));
    final itemRows = _store.rows(_items)..sort((a, b) => _position(a).compareTo(_position(b)));

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
  Future<void> saveFull(Program program) async {
    _store.upsert(_programs, program.toMap());
    _store.upsertAll(_days, program.days.map((d) => d.toMap()));
    _store.upsertAll(_items, [
      for (final day in program.days) ...day.exercises.map((e) => e.toMap()),
    ]);
  }

  @override
  Future<void> saveProgram(Program program) async => _store.upsert(_programs, program.toMap());

  @override
  Future<void> setActive(String programId) async {
    _store.modify(_programs, (row) {
      final shouldBeActive = row['id'] == programId ? 1 : 0;
      if ((readInt(row['is_active']) ?? 0) == shouldBeActive) return false;
      row['is_active'] = shouldBeActive;
      return true;
    });
  }

  Set<String> _dayIdsOf(String programId) => {
        for (final day in _store.rows(_days))
          if (day['program_id'] == programId) day['id']! as String,
      };

  @override
  Future<void> deleteProgram(String programId) async {
    final dayIds = _dayIdsOf(programId);
    _store.softDelete(_items, (row) => dayIds.contains(row['day_id']));
    _store.softDelete(_days, (row) => row['program_id'] == programId);
    _store.softDelete(_programs, (row) => row['id'] == programId);
  }

  @override
  Future<void> saveDay(ProgramDay day) async => _store.upsert(_days, day.toMap());

  @override
  Future<void> deleteDay(String dayId) async {
    _store.softDelete(_items, (row) => row['day_id'] == dayId);
    _store.softDelete(_days, (row) => row['id'] == dayId);
  }

  @override
  Future<void> saveProgramExercise(ProgramExercise exercise) async =>
      _store.upsert(_items, exercise.toMap());

  @override
  Future<void> saveProgramExercises(List<ProgramExercise> exercises) async =>
      _store.upsertAll(_items, exercises.map((e) => e.toMap()));

  @override
  Future<void> deleteProgramExercise(String id) async =>
      _store.softDelete(_items, (row) => row['id'] == id);
}
