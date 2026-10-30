import 'package:flutter_test/flutter_test.dart';

import 'package:gsu_fit/features/profile/domain/user_profile.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/program_generator.dart';

UserProfile profile({
  FitnessGoal goal = FitnessGoal.muscleGain,
  ExperienceLevel experience = ExperienceLevel.intermediate,
  int days = 3,
}) =>
    UserProfile(
      id: 'p',
      name: 'Test',
      age: 30,
      heightCm: 180,
      weightKg: 80,
      sex: Sex.male,
      goal: goal,
      experience: experience,
      daysPerWeek: days,
    );

final labels = ProgramLabels(
  programName: (split, days) => '${split.name}-$days',
  description: (split, goal) => '${split.name}/${goal.name}',
  dayName: (template) => template.name,
);

void main() {
  var counter = 0;
  final generator = ProgramGenerator(
    labels: labels,
    idGenerator: () => 'id${counter++}',
    clock: () => DateTime(2026, 1, 5),
  );

  group('recommendSplit', () {
    test('full body for two or three days', () {
      expect(ProgramGenerator.recommendSplit(ExperienceLevel.advanced, 2), ProgramSplit.fullBody);
      expect(ProgramGenerator.recommendSplit(ExperienceLevel.intermediate, 3), ProgramSplit.fullBody);
    });

    test('upper/lower for four days', () {
      expect(ProgramGenerator.recommendSplit(ExperienceLevel.intermediate, 4), ProgramSplit.upperLower);
    });

    test('beginners stay on upper/lower with more days', () {
      expect(ProgramGenerator.recommendSplit(ExperienceLevel.beginner, 6), ProgramSplit.upperLower);
    });

    test('hybrid for five days and PPL for six', () {
      expect(ProgramGenerator.recommendSplit(ExperienceLevel.advanced, 5), ProgramSplit.hybrid);
      expect(ProgramGenerator.recommendSplit(ExperienceLevel.advanced, 6), ProgramSplit.pushPullLegs);
    });

    test('clamps out-of-range day counts', () {
      expect(ProgramGenerator.recommendSplit(ExperienceLevel.advanced, 1), ProgramSplit.fullBody);
      expect(ProgramGenerator.recommendSplit(ExperienceLevel.advanced, 7), ProgramSplit.pushPullLegs);
    });
  });

  group('templatesFor', () {
    test('day counts match the split', () {
      expect(ProgramGenerator.templatesFor(ProgramSplit.fullBody, 2), hasLength(2));
      expect(ProgramGenerator.templatesFor(ProgramSplit.fullBody, 3), hasLength(3));
      expect(ProgramGenerator.templatesFor(ProgramSplit.upperLower, 4), hasLength(4));
      expect(ProgramGenerator.templatesFor(ProgramSplit.hybrid, 5), hasLength(5));
      expect(ProgramGenerator.templatesFor(ProgramSplit.pushPullLegs, 3), hasLength(3));
      expect(ProgramGenerator.templatesFor(ProgramSplit.pushPullLegs, 6), hasLength(6));
    });
  });

  group('prescription', () {
    test('muscle gain compounds use 6–10 reps for experienced lifters', () {
      final rx = ProgramGenerator.prescription(
        goal: FitnessGoal.muscleGain,
        experience: ExperienceLevel.advanced,
        compound: true,
      );
      expect([rx.minReps, rx.maxReps], [6, 10]);
      expect(rx.sets, 4);
    });

    test('beginners never go below 8 reps', () {
      final rx = ProgramGenerator.prescription(
        goal: FitnessGoal.muscleGain,
        experience: ExperienceLevel.beginner,
        compound: true,
      );
      expect(rx.minReps, 8);
      expect(rx.sets, 3);
    });

    test('endurance uses high reps and short rest', () {
      final rx = ProgramGenerator.prescription(
        goal: FitnessGoal.endurance,
        experience: ExperienceLevel.intermediate,
        compound: false,
      );
      expect(rx.minReps, greaterThanOrEqualTo(15));
      expect(rx.restSeconds, lessThanOrEqualTo(45));
    });

    test('lower body compounds progress faster than isolation work', () {
      final squat = ProgramGenerator.prescription(
        goal: FitnessGoal.generalHealth,
        experience: ExperienceLevel.intermediate,
        compound: true,
        lowerBody: true,
      );
      final curl = ProgramGenerator.prescription(
        goal: FitnessGoal.generalHealth,
        experience: ExperienceLevel.intermediate,
        compound: false,
      );
      expect(squat.incrementKg, 5);
      expect(curl.incrementKg, 1);
    });

    test('timed and bodyweight work adds no load', () {
      final plank = ProgramGenerator.prescription(
        goal: FitnessGoal.muscleGain,
        experience: ExperienceLevel.advanced,
        compound: false,
        bodyweight: true,
        timed: true,
      );
      expect(plank.incrementKg, 0);
      expect([plank.minReps, plank.maxReps], [30, 60]);
    });
  });

  group('generate', () {
    test('builds a full program from the profile', () {
      final program = generator.generate(profile(days: 4));
      expect(program.split, ProgramSplit.upperLower);
      expect(program.days, hasLength(4));
      expect(program.name, 'upperLower-4');
      expect(program.startDate, DateTime(2026, 1, 5));
      for (final (index, day) in program.days.indexed) {
        expect(day.position, index);
        expect(day.programId, program.id);
        expect(day.exercises, isNotEmpty);
        for (final item in day.exercises) {
          expect(item.dayId, day.id);
          expect(item.minReps, lessThanOrEqualTo(item.maxReps));
        }
      }
    });

    test('ids are unique', () {
      final program = generator.generate(profile(days: 6, experience: ExperienceLevel.advanced));
      final ids = [
        program.id,
        for (final day in program.days) ...[day.id, for (final e in day.exercises) e.id],
      ];
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('repeated templates get numbered names', () {
      final program = generator.generate(profile(days: 6, experience: ExperienceLevel.advanced));
      final names = program.days.map((d) => d.name).toList();
      expect(names, containsAll(['push', 'push 2', 'pull 2', 'legs 2']));
    });

    test('beginners get easier exercise variants', () {
      final program = generator.generate(
        profile(experience: ExperienceLevel.beginner, days: 4),
      );
      final exerciseIds = {
        for (final day in program.days) ...day.exercises.map((e) => e.exerciseId),
      };
      expect(exerciseIds, isNot(contains(SeedIds.backSquat)));
      expect(exerciseIds, isNot(contains(SeedIds.pullUp)));
      expect(exerciseIds, contains(SeedIds.gobletSquat));
    });

    test('an explicit split overrides the recommendation', () {
      final program = generator.generate(profile(days: 3), split: ProgramSplit.pushPullLegs, days: 3);
      expect(program.split, ProgramSplit.pushPullLegs);
      expect(program.days, hasLength(3));
    });
  });

  test('defaultWeekdays spreads training across the week', () {
    expect(ProgramGenerator.defaultWeekdays(3), [1, 3, 5]);
    expect(ProgramGenerator.defaultWeekdays(4), [1, 2, 4, 5]);
    expect(ProgramGenerator.defaultWeekdays(9), hasLength(7));
  });
}
