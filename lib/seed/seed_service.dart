import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/program_generator.dart';
import 'package:gsu_fit/features/programs/presentation/program_labels.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';
import 'package:gsu_fit/seed/seed_exercises.dart';

/// Installs the exercise library and a sample program on first launch.
/// Versioned so later releases can add more seed content without
/// touching what the user already has. Works on any storage backend.
class SeedService {
  SeedService({required this.settings, required this.exercises, required this.programs});

  final SettingsRepository settings;
  final ExerciseRepository exercises;
  final ProgramRepository programs;

  static const int currentVersion = 1;
  static const String _versionKey = 'seed_version';

  Future<void> seedIfNeeded(AppLocalizations l) async {
    final version = int.tryParse(await settings.getValue(_versionKey) ?? '') ?? 0;
    if (version >= currentVersion) return;

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
      await programs.saveFull(
        program.copyWith(name: l.sampleProgramName, description: l.sampleProgramDescription),
      );
    }

    await settings.setValue(_versionKey, '$currentVersion');
  }
}
