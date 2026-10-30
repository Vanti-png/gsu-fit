import 'package:flutter_test/flutter_test.dart';

import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/progression.dart';

ProgramExercise target({
  int sets = 3,
  int minReps = 8,
  int maxReps = 12,
  double start = 40,
  double increment = 2.5,
}) =>
    ProgramExercise(
      id: 'pe',
      dayId: 'd',
      exerciseId: 'e',
      position: 0,
      sets: sets,
      minReps: minReps,
      maxReps: maxReps,
      restSeconds: 90,
      startWeightKg: start,
      incrementKg: increment,
    );

List<SetResult> session(double weight, List<int> reps) =>
    [for (final r in reps) SetResult(weightKg: weight, reps: r)];

void main() {
  const calculator = ProgressionCalculator();

  test('first session uses the start weight and the bottom of the range', () {
    final s = calculator.suggest(target: target(), history: const []);
    expect(s.reason, ProgressionReason.firstSession);
    expect(s.weightKg, 40);
    expect(s.reps, 8);
  });

  test('adds weight once every set reaches the top of the range', () {
    final s = calculator.suggest(target: target(), history: [session(50, [12, 12, 12])]);
    expect(s.reason, ProgressionReason.increaseWeight);
    expect(s.weightKg, 52.5);
    expect(s.reps, 8);
  });

  test('adds a rep while still inside the range', () {
    final s = calculator.suggest(target: target(), history: [session(50, [10, 9, 9])]);
    expect(s.reason, ProgressionReason.increaseReps);
    expect(s.weightKg, 50);
    expect(s.reps, 10);
  });

  test('never suggests more reps than the top of the range', () {
    final s = calculator.suggest(target: target(), history: [session(50, [12, 12, 11])]);
    expect(s.reason, ProgressionReason.increaseReps);
    expect(s.reps, 12);
  });

  test('repeats the load after one missed session', () {
    final s = calculator.suggest(target: target(), history: [session(50, [8, 7, 6])]);
    expect(s.reason, ProgressionReason.repeat);
    expect(s.weightKg, 50);
    expect(s.reps, 8);
  });

  test('missing sets counts as a miss', () {
    final s = calculator.suggest(target: target(), history: [session(50, [12, 12])]);
    expect(s.reason, ProgressionReason.repeat);
  });

  test('deloads about 10% after two missed sessions in a row', () {
    final s = calculator.suggest(
      target: target(),
      history: [session(60, [7, 6, 6]), session(60, [7, 7, 6])],
    );
    expect(s.reason, ProgressionReason.deload);
    // 60 × 0.9 = 54 → nearest 2.5 kg step
    expect(s.weightKg, 55);
  });

  test('only the heaviest sets count as working sets', () {
    final history = [
      [
        const SetResult(weightKg: 40, reps: 12),
        const SetResult(weightKg: 60, reps: 12),
        const SetResult(weightKg: 60, reps: 12),
        const SetResult(weightKg: 60, reps: 12),
      ],
    ];
    final s = calculator.suggest(target: target(), history: history);
    expect(s.reason, ProgressionReason.increaseWeight);
    expect(s.weightKg, 62.5);
  });

  test('ignores sets that were not completed', () {
    final history = [
      [
        const SetResult(weightKg: 50, reps: 12),
        const SetResult(weightKg: 50, reps: 12),
        const SetResult(weightKg: 50, reps: 12),
        const SetResult(weightKg: 80, reps: 1, completed: false),
      ],
    ];
    final s = calculator.suggest(target: target(), history: history);
    expect(s.weightKg, 52.5);
  });

  test('bodyweight work progresses by beating the best set', () {
    final s = calculator.suggest(
      target: target(start: 0, increment: 0),
      history: [session(0, [10, 9, 8])],
      bodyweight: true,
    );
    expect(s.reason, ProgressionReason.beatBest);
    expect(s.reps, 11);
  });

  test('timed holds add seconds', () {
    final s = calculator.suggest(
      target: target(minReps: 30, maxReps: 60, start: 0, increment: 0),
      history: [session(0, [45, 40, 40])],
      bodyweight: true,
      repStep: 5,
    );
    expect(s.reps, 50);
  });

  test('weighted bodyweight exercises use normal double progression', () {
    final s = calculator.suggest(
      target: target(increment: 2.5),
      history: [session(10, [12, 12, 12])],
      bodyweight: true,
    );
    expect(s.reason, ProgressionReason.increaseWeight);
    expect(s.weightKg, 12.5);
  });

  group('estimateOneRepMax', () {
    test('uses the Epley formula', () {
      expect(estimateOneRepMax(100, 10), closeTo(133.33, 0.01));
    });

    test('returns the weight itself for a single rep', () {
      expect(estimateOneRepMax(120, 1), 120);
    });

    test('is zero without load or reps', () {
      expect(estimateOneRepMax(0, 10), 0);
      expect(estimateOneRepMax(100, 0), 0);
    });
  });
}
