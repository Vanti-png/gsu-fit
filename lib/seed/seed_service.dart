import 'package:gsu_fit/core/database/app_database.dart';
import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';
import 'package:gsu_fit/features/programs/data/sqlite_program_repository.dart';
import 'package:gsu_fit/features/programs/domain/program_generator.dart';
import 'package:gsu_fit/features/programs/presentation/program_labels.dart';
import 'package:gsu_fit/features/settings/data/sqlite_settings_repository.dart';
import 'package:gsu_fit/seed/seed_exercises.dart';

/// Installs the exercise library and a sample program on first launch.
/// Versioned so later releases can add more seed content without
/// touching what the user already has.
class SeedService {
  SeedService(this._database);

  final AppDatabase _database;

  static const int currentVersion = 1;
  static const String _versionKey = 'seed_version';

  Future<void> seedIfNeeded(AppLocalizations l) async {
    final settings = SqliteSettingsRepository(_database);
    final version = int.tryParse(await settings.getValue(_versionKey) ?? '') ?? 0;
    if (version >= currentVersion) return;

    final exercises = SqliteExerciseRepository(_database);
    for (final exercise in seedExercises) {
      if (await exercises.getById(exercise.id) == null) {
        await exercises.save(exercise);
      }
    }

    if (version < 1) {
      // A ready-made beginner full-body plan the user can try or delete.
      const sampleProfile = UserProfile(
        id: 'sample',
        name: '',
        age: 30,
        heightCm: 170,
        weightKg: 70,
        sex: Sex.unspecified,
        goal: FitnessGoal.generalHealth,
        experience: ExperienceLevel.beginner,
        daysPerWeek: 3,
      );
      final program = ProgramGenerator(labels: programLabels(l)).generate(sampleProfile);
      await SqliteProgramRepository(_database).saveFull(
        program.copyWith(name: l.sampleProgramName, description: l.sampleProgramDescription),
      );
    }

    await settings.setValue(_versionKey, '$currentVersion');
  }
}
