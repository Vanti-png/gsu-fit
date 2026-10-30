import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/program_generator.dart';

/// Turkish names for generated programs and their days.
ProgramLabels programLabels(AppLocalizations l) => ProgramLabels(
      programName: (split, days) => switch (split) {
        ProgramSplit.fullBody => l.programNameFullBody('$days'),
        ProgramSplit.upperLower => l.programNameUpperLower('$days'),
        ProgramSplit.pushPullLegs => l.programNamePpl('$days'),
        ProgramSplit.hybrid => l.programNameHybrid('$days'),
        ProgramSplit.custom => l.programNameCustom,
      },
      description: (split, goal) {
        final text = l.programDescription(l.split(split), l.goal(goal));
        return goal == FitnessGoal.weightLoss ? '$text ${l.programCardioTip}' : text;
      },
      dayName: (template) => switch (template) {
        DayTemplate.fullBodyA => l.dayFullBodyA,
        DayTemplate.fullBodyB => l.dayFullBodyB,
        DayTemplate.fullBodyC => l.dayFullBodyC,
        DayTemplate.upperA => l.dayUpperA,
        DayTemplate.lowerA => l.dayLowerA,
        DayTemplate.upperB => l.dayUpperB,
        DayTemplate.lowerB => l.dayLowerB,
        DayTemplate.push => l.dayPush,
        DayTemplate.pull => l.dayPull,
        DayTemplate.legs => l.dayLegs,
      },
    );
