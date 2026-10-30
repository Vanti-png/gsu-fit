import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';

/// Building blocks for generated programs.
enum DayTemplate { fullBodyA, fullBodyB, fullBodyC, upperA, lowerA, upperB, lowerB, push, pull, legs }

/// Display texts are injected so this file stays free of UI and
/// localization code (and easy to unit test).
class ProgramLabels {
  const ProgramLabels({
    required this.programName,
    required this.description,
    required this.dayName,
  });

  final String Function(ProgramSplit split, int days) programName;
  final String Function(ProgramSplit split, FitnessGoal goal) description;
  final String Function(DayTemplate template) dayName;
}

class _Slot {
  const _Slot(
    this.exerciseId, {
    this.compound = false,
    this.lowerBody = false,
    this.bodyweight = false,
    this.timed = false,
  });

  final String exerciseId;
  final bool compound;
  final bool lowerBody;
  final bool bodyweight;
  final bool timed;
}

class Prescription {
  const Prescription({
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.restSeconds,
    required this.incrementKg,
  });

  final int sets;
  final int minReps;
  final int maxReps;
  final int restSeconds;
  final double incrementKg;
}

/// Seed exercise ids used by the templates (see lib/seed/seed_exercises.dart).
class SeedIds {
  static const backSquat = 'ex_back_squat';
  static const gobletSquat = 'ex_goblet_squat';
  static const benchPress = 'ex_bench_press';
  static const inclineDbPress = 'ex_incline_db_press';
  static const pushUp = 'ex_push_up';
  static const dips = 'ex_dips';
  static const overheadPress = 'ex_overhead_press';
  static const dbShoulderPress = 'ex_db_shoulder_press';
  static const lateralRaise = 'ex_lateral_raise';
  static const barbellRow = 'ex_barbell_row';
  static const pullUp = 'ex_pull_up';
  static const latPulldown = 'ex_lat_pulldown';
  static const seatedRow = 'ex_seated_row';
  static const facePull = 'ex_face_pull';
  static const deadlift = 'ex_deadlift';
  static const romanianDeadlift = 'ex_romanian_deadlift';
  static const hipThrust = 'ex_hip_thrust';
  static const legPress = 'ex_leg_press';
  static const legExtension = 'ex_leg_extension';
  static const legCurl = 'ex_leg_curl';
  static const lunge = 'ex_lunge';
  static const calfRaise = 'ex_calf_raise';
  static const dbCurl = 'ex_db_curl';
  static const hammerCurl = 'ex_hammer_curl';
  static const tricepsPushdown = 'ex_triceps_pushdown';
  static const overheadTriceps = 'ex_overhead_triceps';
  static const plank = 'ex_plank';
  static const crunch = 'ex_crunch';
  static const mountainClimber = 'ex_mountain_climber';
}

class ProgramGenerator {
  ProgramGenerator({required this.labels, String Function()? idGenerator, DateTime Function()? clock})
      : _newId = idGenerator ?? newId,
        _clock = clock ?? DateTime.now;

  final ProgramLabels labels;
  final String Function() _newId;
  final DateTime Function() _clock;

  static const _templates = <DayTemplate, List<_Slot>>{
    DayTemplate.fullBodyA: [
      _Slot(SeedIds.backSquat, compound: true, lowerBody: true),
      _Slot(SeedIds.benchPress, compound: true),
      _Slot(SeedIds.barbellRow, compound: true),
      _Slot(SeedIds.lateralRaise),
      _Slot(SeedIds.plank, bodyweight: true, timed: true),
    ],
    DayTemplate.fullBodyB: [
      _Slot(SeedIds.romanianDeadlift, compound: true, lowerBody: true),
      _Slot(SeedIds.overheadPress, compound: true),
      _Slot(SeedIds.latPulldown, compound: true),
      _Slot(SeedIds.lunge, compound: true, lowerBody: true),
      _Slot(SeedIds.dbCurl),
    ],
    DayTemplate.fullBodyC: [
      _Slot(SeedIds.legPress, compound: true, lowerBody: true),
      _Slot(SeedIds.inclineDbPress, compound: true),
      _Slot(SeedIds.seatedRow, compound: true),
      _Slot(SeedIds.tricepsPushdown),
      _Slot(SeedIds.crunch, bodyweight: true),
    ],
    DayTemplate.upperA: [
      _Slot(SeedIds.benchPress, compound: true),
      _Slot(SeedIds.barbellRow, compound: true),
      _Slot(SeedIds.overheadPress, compound: true),
      _Slot(SeedIds.latPulldown, compound: true),
      _Slot(SeedIds.dbCurl),
      _Slot(SeedIds.tricepsPushdown),
    ],
    DayTemplate.lowerA: [
      _Slot(SeedIds.backSquat, compound: true, lowerBody: true),
      _Slot(SeedIds.romanianDeadlift, compound: true, lowerBody: true),
      _Slot(SeedIds.legExtension, lowerBody: true),
      _Slot(SeedIds.legCurl, lowerBody: true),
      _Slot(SeedIds.calfRaise, lowerBody: true),
      _Slot(SeedIds.plank, bodyweight: true, timed: true),
    ],
    DayTemplate.upperB: [
      _Slot(SeedIds.inclineDbPress, compound: true),
      _Slot(SeedIds.seatedRow, compound: true),
      _Slot(SeedIds.dbShoulderPress, compound: true),
      _Slot(SeedIds.pullUp, compound: true, bodyweight: true),
      _Slot(SeedIds.hammerCurl),
      _Slot(SeedIds.overheadTriceps),
    ],
    DayTemplate.lowerB: [
      _Slot(SeedIds.deadlift, compound: true, lowerBody: true),
      _Slot(SeedIds.legPress, compound: true, lowerBody: true),
      _Slot(SeedIds.lunge, compound: true, lowerBody: true),
      _Slot(SeedIds.legCurl, lowerBody: true),
      _Slot(SeedIds.calfRaise, lowerBody: true),
      _Slot(SeedIds.crunch, bodyweight: true),
    ],
    DayTemplate.push: [
      _Slot(SeedIds.benchPress, compound: true),
      _Slot(SeedIds.overheadPress, compound: true),
      _Slot(SeedIds.inclineDbPress, compound: true),
      _Slot(SeedIds.lateralRaise),
      _Slot(SeedIds.tricepsPushdown),
      _Slot(SeedIds.dips, compound: true, bodyweight: true),
    ],
    DayTemplate.pull: [
      _Slot(SeedIds.deadlift, compound: true, lowerBody: true),
      _Slot(SeedIds.pullUp, compound: true, bodyweight: true),
      _Slot(SeedIds.seatedRow, compound: true),
      _Slot(SeedIds.facePull),
      _Slot(SeedIds.dbCurl),
      _Slot(SeedIds.hammerCurl),
    ],
    DayTemplate.legs: [
      _Slot(SeedIds.backSquat, compound: true, lowerBody: true),
      _Slot(SeedIds.romanianDeadlift, compound: true, lowerBody: true),
      _Slot(SeedIds.legPress, compound: true, lowerBody: true),
      _Slot(SeedIds.legCurl, lowerBody: true),
      _Slot(SeedIds.calfRaise, lowerBody: true),
      _Slot(SeedIds.plank, bodyweight: true, timed: true),
    ],
  };

  /// Easier variants for beginners.
  static const _beginnerSwaps = <String, _Slot>{
    SeedIds.backSquat: _Slot(SeedIds.gobletSquat, compound: true, lowerBody: true),
    SeedIds.deadlift: _Slot(SeedIds.romanianDeadlift, compound: true, lowerBody: true),
    SeedIds.pullUp: _Slot(SeedIds.latPulldown, compound: true),
    SeedIds.dips: _Slot(SeedIds.pushUp, compound: true, bodyweight: true),
  };

  /// 2–3 days: full body. 4: upper/lower. 5: push/pull/legs + upper/lower.
  /// 6: push/pull/legs twice. Beginners are capped at upper/lower.
  static ProgramSplit recommendSplit(ExperienceLevel experience, int daysPerWeek) {
    final days = daysPerWeek.clamp(2, 6);
    if (days <= 3) return ProgramSplit.fullBody;
    if (days == 4 || experience == ExperienceLevel.beginner) return ProgramSplit.upperLower;
    if (days == 5) return ProgramSplit.hybrid;
    return ProgramSplit.pushPullLegs;
  }

  static List<DayTemplate> templatesFor(ProgramSplit split, int daysPerWeek) {
    final days = daysPerWeek.clamp(2, 6);
    return switch (split) {
      ProgramSplit.fullBody => days <= 2
          ? const [DayTemplate.fullBodyA, DayTemplate.fullBodyB]
          : const [DayTemplate.fullBodyA, DayTemplate.fullBodyB, DayTemplate.fullBodyC],
      ProgramSplit.upperLower => const [
          DayTemplate.upperA,
          DayTemplate.lowerA,
          DayTemplate.upperB,
          DayTemplate.lowerB,
        ],
      ProgramSplit.hybrid => const [
          DayTemplate.push,
          DayTemplate.pull,
          DayTemplate.legs,
          DayTemplate.upperB,
          DayTemplate.lowerB,
        ],
      ProgramSplit.pushPullLegs => days >= 6
          ? const [
              DayTemplate.push,
              DayTemplate.pull,
              DayTemplate.legs,
              DayTemplate.push,
              DayTemplate.pull,
              DayTemplate.legs,
            ]
          : const [DayTemplate.push, DayTemplate.pull, DayTemplate.legs],
      ProgramSplit.custom => const [DayTemplate.fullBodyA],
    };
  }

  /// Sets, reps and rest by goal and experience.
  static Prescription prescription({
    required FitnessGoal goal,
    required ExperienceLevel experience,
    required bool compound,
    bool lowerBody = false,
    bool bodyweight = false,
    bool timed = false,
  }) {
    final sets = switch (experience) {
      ExperienceLevel.beginner => 3,
      ExperienceLevel.intermediate => compound ? 4 : 3,
      ExperienceLevel.advanced => 4,
    };
    if (timed) {
      return Prescription(sets: 3, minReps: 30, maxReps: 60, restSeconds: 60, incrementKg: 0);
    }
    var (minReps, maxReps, rest) = switch (goal) {
      FitnessGoal.muscleGain => compound ? (6, 10, 120) : (10, 15, 75),
      FitnessGoal.weightLoss => compound ? (10, 12, 60) : (12, 15, 45),
      FitnessGoal.endurance => compound ? (12, 15, 45) : (15, 20, 30),
      FitnessGoal.generalHealth => compound ? (8, 12, 90) : (10, 15, 60),
    };
    if (experience == ExperienceLevel.beginner && minReps < 8) {
      minReps = 8;
      maxReps = 12;
    }
    final increment = bodyweight
        ? 0.0
        : compound
            ? (lowerBody ? 5.0 : 2.5)
            : 1.0;
    return Prescription(
      sets: sets,
      minReps: minReps,
      maxReps: maxReps,
      restSeconds: rest,
      incrementKg: increment,
    );
  }

  /// Weekdays (1 = Monday) spread across the week for [daysPerWeek].
  static List<int> defaultWeekdays(int daysPerWeek) => switch (daysPerWeek.clamp(1, 7)) {
        1 => const [1],
        2 => const [1, 4],
        3 => const [1, 3, 5],
        4 => const [1, 2, 4, 5],
        5 => const [1, 2, 3, 4, 5],
        6 => const [1, 2, 3, 4, 5, 6],
        _ => const [1, 2, 3, 4, 5, 6, 7],
      };

  Program generate(UserProfile profile, {ProgramSplit? split, int? days}) {
    final daysPerWeek = (days ?? profile.daysPerWeek).clamp(2, 6);
    final chosen = split ?? recommendSplit(profile.experience, daysPerWeek);
    final templates = templatesFor(chosen, daysPerWeek);
    final programId = _newId();
    final occurrences = <DayTemplate, int>{};

    final programDays = <ProgramDay>[];
    for (var dayIndex = 0; dayIndex < templates.length; dayIndex++) {
      final template = templates[dayIndex];
      final count = (occurrences[template] ?? 0) + 1;
      occurrences[template] = count;
      final dayId = _newId();
      final slots = _templates[template]!;
      final exercises = <ProgramExercise>[];
      for (var position = 0; position < slots.length; position++) {
        var slot = slots[position];
        if (profile.experience == ExperienceLevel.beginner) {
          slot = _beginnerSwaps[slot.exerciseId] ?? slot;
        }
        final rx = prescription(
          goal: profile.goal,
          experience: profile.experience,
          compound: slot.compound,
          lowerBody: slot.lowerBody,
          bodyweight: slot.bodyweight,
          timed: slot.timed,
        );
        exercises.add(ProgramExercise(
          id: _newId(),
          dayId: dayId,
          exerciseId: slot.exerciseId,
          position: position,
          sets: rx.sets,
          minReps: rx.minReps,
          maxReps: rx.maxReps,
          restSeconds: rx.restSeconds,
          incrementKg: rx.incrementKg,
        ));
      }
      final baseName = labels.dayName(template);
      programDays.add(ProgramDay(
        id: dayId,
        programId: programId,
        name: count > 1 ? '$baseName $count' : baseName,
        position: dayIndex,
        exercises: exercises,
      ));
    }

    return Program(
      id: programId,
      name: labels.programName(chosen, programDays.length),
      description: labels.description(chosen, profile.goal),
      split: chosen,
      durationWeeks: 8,
      startDate: _clock(),
      days: programDays,
    );
  }
}
