import 'dart:math';

import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';

enum ProgressionReason {
  /// No history yet: start at the programmed weight and the bottom of the range.
  firstSession,

  /// Every set reached the top of the rep range: add load, reset reps.
  increaseWeight,

  /// All sets were inside the range: same load, one more rep.
  increaseReps,

  /// Missed the range once: repeat the same load.
  repeat,

  /// Missed the range twice in a row: drop the load about 10%.
  deload,

  /// Bodyweight or timed exercise: beat the previous best.
  beatBest,
}

class SetResult {
  const SetResult({required this.weightKg, required this.reps, this.completed = true});

  final double weightKg;
  final int reps;
  final bool completed;
}

class ProgressionSuggestion {
  const ProgressionSuggestion({
    required this.weightKg,
    required this.reps,
    required this.reason,
  });

  final double weightKg;
  final int reps;
  final ProgressionReason reason;
}

/// Double progression: work up to the top of the rep range at a given load,
/// then increase the load and start again from the bottom of the range.
class ProgressionCalculator {
  const ProgressionCalculator({this.roundingStepKg = 2.5, this.deloadFactor = 0.9});

  /// Plate step used when rounding a deload.
  final double roundingStepKg;
  final double deloadFactor;

  /// [history] holds earlier sessions of this exercise, most recent first.
  /// [repStep] is how much to add for bodyweight/timed work (1 rep, 5 s…).
  ProgressionSuggestion suggest({
    required ProgramExercise target,
    required List<List<SetResult>> history,
    bool bodyweight = false,
    int repStep = 1,
  }) {
    final last = history.isEmpty
        ? const <SetResult>[]
        : history.first.where((s) => s.completed).toList();
    if (last.isEmpty) {
      return ProgressionSuggestion(
        weightKg: target.startWeightKg,
        reps: target.minReps,
        reason: ProgressionReason.firstSession,
      );
    }

    final workingWeight = last.map((s) => s.weightKg).reduce(max);

    if (bodyweight && workingWeight <= 0) {
      final best = last.map((s) => s.reps).reduce(max);
      return ProgressionSuggestion(
        weightKg: 0,
        reps: best + repStep,
        reason: ProgressionReason.beatBest,
      );
    }

    final working = _workingSets(last, workingWeight);
    final lowestReps = working.map((s) => s.reps).reduce(min);
    final allSetsDone = working.length >= target.sets;

    if (allSetsDone && lowestReps >= target.maxReps) {
      return ProgressionSuggestion(
        weightKg: cleanDouble(workingWeight + target.incrementKg),
        reps: target.minReps,
        reason: ProgressionReason.increaseWeight,
      );
    }

    if (allSetsDone && lowestReps >= target.minReps) {
      return ProgressionSuggestion(
        weightKg: workingWeight,
        reps: min(target.maxReps, lowestReps + 1),
        reason: ProgressionReason.increaseReps,
      );
    }

    final missedBefore = history.length >= 2 && _missed(history[1], target);
    if (missedBefore) {
      final reduced = roundToStep(workingWeight * deloadFactor, roundingStepKg);
      return ProgressionSuggestion(
        weightKg: cleanDouble(max(0.0, min(reduced, workingWeight))),
        reps: target.minReps,
        reason: ProgressionReason.deload,
      );
    }

    return ProgressionSuggestion(
      weightKg: workingWeight,
      reps: target.minReps,
      reason: ProgressionReason.repeat,
    );
  }

  List<SetResult> _workingSets(List<SetResult> sets, double workingWeight) =>
      sets.where((s) => s.weightKg >= workingWeight - 0.001).toList();

  bool _missed(List<SetResult> session, ProgramExercise target) {
    final done = session.where((s) => s.completed).toList();
    if (done.isEmpty) return true;
    final weight = done.map((s) => s.weightKg).reduce(max);
    final working = _workingSets(done, weight);
    return working.length < target.sets ||
        working.map((s) => s.reps).reduce(min) < target.minReps;
  }
}

/// Epley estimate of the one-rep max.
double estimateOneRepMax(double weightKg, int reps) {
  if (reps <= 0 || weightKg <= 0) return 0;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}
