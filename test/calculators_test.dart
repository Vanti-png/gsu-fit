import 'package:flutter_test/flutter_test.dart';

import 'package:gsu_fit/features/cardio/domain/calorie_calculator.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';
import 'package:gsu_fit/features/nutrition/domain/nutrition.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';

void main() {
  group('CalorieCalculator', () {
    test('uses MET × kg × hours', () {
      // 30 min swimming, 70 kg, MET 6 → 6 × 70 × 0.5 = 210
      final kcal = CalorieCalculator.estimate(
        type: CardioType.swimming,
        duration: const Duration(minutes: 30),
        weightKg: 70,
      );
      expect(kcal, closeTo(210, 0.001));
    });

    test('faster running burns more per hour', () {
      double run(double km) => CalorieCalculator.estimate(
            type: CardioType.running,
            duration: const Duration(hours: 1),
            weightKg: 70,
            distanceKm: km,
          );
      expect(run(12), greaterThan(run(8)));
    });

    test('no duration or weight means no calories', () {
      expect(
        CalorieCalculator.estimate(type: CardioType.walking, duration: Duration.zero, weightKg: 70),
        0,
      );
      expect(
        CalorieCalculator.estimate(
          type: CardioType.walking,
          duration: const Duration(minutes: 10),
          weightKg: 0,
        ),
        0,
      );
    });

    test('pace per kilometre', () {
      final pace = CalorieCalculator.pacePerKm(const Duration(minutes: 50), 10);
      expect(pace, const Duration(minutes: 5));
      expect(CalorieCalculator.pacePerKm(const Duration(minutes: 50), null), isNull);
      expect(CalorieCalculator.pacePerKm(const Duration(minutes: 50), 0), isNull);
    });

    test('strength training estimate', () {
      expect(
        CalorieCalculator.strength(duration: const Duration(hours: 1), weightKg: 80),
        closeTo(400, 0.001),
      );
    });
  });

  group('NutritionCalculator', () {
    const base = UserProfile(
      id: 'p',
      name: '',
      age: 30,
      heightCm: 180,
      weightKg: 80,
      sex: Sex.male,
      goal: FitnessGoal.generalHealth,
      experience: ExperienceLevel.intermediate,
      daysPerWeek: 3,
    );

    test('Mifflin-St Jeor BMR', () {
      // 10×80 + 6.25×180 − 5×30 + 5 = 1780
      expect(
        NutritionCalculator.bmr(weightKg: 80, heightCm: 180, age: 30, sex: Sex.male),
        closeTo(1780, 0.001),
      );
      expect(
        NutritionCalculator.bmr(weightKg: 80, heightCm: 180, age: 30, sex: Sex.female),
        closeTo(1614, 0.001),
      );
    });

    test('maintenance calories for general health', () {
      final targets = NutritionCalculator.targets(base);
      // 1780 × 1.375 = 2447.5
      expect(targets.calories, 2448);
    });

    test('weight loss subtracts and muscle gain adds calories', () {
      final maintain = NutritionCalculator.targets(base).calories;
      final cut = NutritionCalculator.targets(base.copyWith(goal: FitnessGoal.weightLoss)).calories;
      final bulk = NutritionCalculator.targets(base.copyWith(goal: FitnessGoal.muscleGain)).calories;
      expect(cut, maintain - 500);
      expect(bulk, maintain + 300);
    });

    test('never goes below the safety minimum', () {
      final tiny = base.copyWith(weightKg: 35, heightCm: 140, age: 90, goal: FitnessGoal.weightLoss);
      expect(NutritionCalculator.targets(tiny).calories, NutritionCalculator.minimumCalories);
    });

    test('macros add up to the calorie target', () {
      final t = NutritionCalculator.targets(base.copyWith(goal: FitnessGoal.muscleGain));
      final fromMacros = t.proteinG * 4 + t.carbsG * 4 + t.fatG * 9;
      expect(fromMacros, closeTo(t.calories, 15));
      expect(t.proteinG, 160);
    });

    test('overrides win over the estimate', () {
      final t = NutritionCalculator.targets(base, calorieOverride: 2000, waterOverride: 3000);
      expect(t.calories, 2000);
      expect(t.waterMl, 3000);
    });

    test('water goal is 35 ml per kg rounded to a glass', () {
      expect(NutritionCalculator.waterGoalMl(80), 2750);
      expect(NutritionCalculator.waterGoalMl(30), 1500);
    });

    test('daily totals', () {
      final totals = NutritionTotals.of(const [
        FoodEntry(id: '1', day: 'd', meal: MealType.lunch, name: 'a', calories: 300, proteinG: 20),
        FoodEntry(id: '2', day: 'd', meal: MealType.dinner, name: 'b', calories: 500, fatG: 10),
      ]);
      expect(totals.calories, 800);
      expect(totals.proteinG, 20);
      expect(totals.fatG, 10);
    });
  });
}
