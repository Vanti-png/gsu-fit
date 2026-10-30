import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';
import 'package:gsu_fit/features/nutrition/domain/nutrition.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/progression.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';

/// Display names for domain enums. Kept here so domain code never imports
/// localization.
extension EnumLabels on AppLocalizations {
  String goal(FitnessGoal value) => switch (value) {
        FitnessGoal.muscleGain => goalMuscleGain,
        FitnessGoal.weightLoss => goalWeightLoss,
        FitnessGoal.endurance => goalEndurance,
        FitnessGoal.generalHealth => goalGeneralHealth,
      };

  String goalHint(FitnessGoal value) => switch (value) {
        FitnessGoal.muscleGain => goalMuscleGainHint,
        FitnessGoal.weightLoss => goalWeightLossHint,
        FitnessGoal.endurance => goalEnduranceHint,
        FitnessGoal.generalHealth => goalGeneralHealthHint,
      };

  String level(ExperienceLevel value) => switch (value) {
        ExperienceLevel.beginner => levelBeginner,
        ExperienceLevel.intermediate => levelIntermediate,
        ExperienceLevel.advanced => levelAdvanced,
      };

  String levelHint(ExperienceLevel value) => switch (value) {
        ExperienceLevel.beginner => levelBeginnerHint,
        ExperienceLevel.intermediate => levelIntermediateHint,
        ExperienceLevel.advanced => levelAdvancedHint,
      };

  String sex(Sex value) => switch (value) {
        Sex.male => sexMale,
        Sex.female => sexFemale,
        Sex.unspecified => sexUnspecified,
      };

  String muscle(MuscleGroup value) => switch (value) {
        MuscleGroup.chest => muscleChest,
        MuscleGroup.back => muscleBack,
        MuscleGroup.shoulders => muscleShoulders,
        MuscleGroup.biceps => muscleBiceps,
        MuscleGroup.triceps => muscleTriceps,
        MuscleGroup.forearms => muscleForearms,
        MuscleGroup.abs => muscleAbs,
        MuscleGroup.quads => muscleQuads,
        MuscleGroup.hamstrings => muscleHamstrings,
        MuscleGroup.glutes => muscleGlutes,
        MuscleGroup.calves => muscleCalves,
        MuscleGroup.lowerBack => muscleLowerBack,
        MuscleGroup.fullBody => muscleFullBody,
      };

  String equipment(Equipment value) => switch (value) {
        Equipment.barbell => equipmentBarbell,
        Equipment.dumbbell => equipmentDumbbell,
        Equipment.machine => equipmentMachine,
        Equipment.cable => equipmentCable,
        Equipment.bodyweight => equipmentBodyweight,
        Equipment.kettlebell => equipmentKettlebell,
        Equipment.band => equipmentBand,
        Equipment.other => equipmentOther,
      };

  String category(ExerciseCategory value) => switch (value) {
        ExerciseCategory.strength => categoryStrength,
        ExerciseCategory.bodyweight => categoryBodyweight,
        ExerciseCategory.cardio => categoryCardio,
        ExerciseCategory.mobility => categoryMobility,
      };

  String split(ProgramSplit value) => switch (value) {
        ProgramSplit.fullBody => splitFullBody,
        ProgramSplit.upperLower => splitUpperLower,
        ProgramSplit.pushPullLegs => splitPushPullLegs,
        ProgramSplit.hybrid => splitHybrid,
        ProgramSplit.custom => splitCustom,
      };

  String cardioType(CardioType value) => switch (value) {
        CardioType.running => cardioRunning,
        CardioType.walking => cardioWalking,
        CardioType.cycling => cardioCycling,
        CardioType.swimming => cardioSwimming,
        CardioType.rowing => cardioRowing,
        CardioType.elliptical => cardioElliptical,
        CardioType.jumpRope => cardioJumpRope,
        CardioType.hiking => cardioHiking,
        CardioType.other => cardioOther,
      };

  String meal(MealType value) => switch (value) {
        MealType.breakfast => mealBreakfast,
        MealType.lunch => mealLunch,
        MealType.dinner => mealDinner,
        MealType.snack => mealSnack,
      };

  String measurementField(MeasurementField value) => switch (value) {
        MeasurementField.weight => measurementWeight,
        MeasurementField.bodyFat => measurementBodyFat,
        MeasurementField.chest => measurementChest,
        MeasurementField.waist => measurementWaist,
        MeasurementField.arm => measurementArm,
        MeasurementField.leg => measurementLeg,
      };

  String progressionReason(ProgressionReason value) => switch (value) {
        ProgressionReason.firstSession => reasonFirstSession,
        ProgressionReason.increaseWeight => reasonIncreaseWeight,
        ProgressionReason.increaseReps => reasonIncreaseReps,
        ProgressionReason.repeat => reasonRepeat,
        ProgressionReason.deload => reasonDeload,
        ProgressionReason.beatBest => reasonBeatBest,
      };

  String themeMode(AppThemeMode value) => switch (value) {
        AppThemeMode.system => themeSystem,
        AppThemeMode.light => themeLight,
        AppThemeMode.dark => themeDark,
      };

  /// 1 = Monday … 7 = Sunday.
  String weekdayShort(int weekday) => switch (weekday) {
        1 => weekdayMon,
        2 => weekdayTue,
        3 => weekdayWed,
        4 => weekdayThu,
        5 => weekdayFri,
        6 => weekdaySat,
        _ => weekdaySun,
      };

  String weekdayLong(int weekday) => switch (weekday) {
        1 => weekdayMonday,
        2 => weekdayTuesday,
        3 => weekdayWednesday,
        4 => weekdayThursday,
        5 => weekdayFriday,
        6 => weekdaySaturday,
        _ => weekdaySunday,
      };

  /// "45 dk" or "1 sa 05 dk".
  String duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    if (hours == 0) return durationMinutes('$minutes');
    return durationHoursMinutes('$hours', minutes.toString().padLeft(2, '0'));
  }
}
