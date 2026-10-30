import 'dart:math';

import 'package:gsu_fit/core/utils/map_read.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';

enum MealType { breakfast, lunch, dinner, snack }

class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.day,
    required this.meal,
    required this.name,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.createdAt,
  });

  final String id;

  /// Day key, see dayKey() in core/utils/dates.dart.
  final String day;
  final MealType meal;
  final String name;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final DateTime? createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'day': day,
        'meal': meal.name,
        'name': name,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory FoodEntry.fromMap(Map<String, Object?> map) => FoodEntry(
        id: map['id']! as String,
        day: readString(map['day']) ?? '',
        meal: readEnum(MealType.values, map['meal'], MealType.snack),
        name: readString(map['name']) ?? '',
        calories: readDouble(map['calories']) ?? 0,
        proteinG: readDouble(map['protein_g']) ?? 0,
        carbsG: readDouble(map['carbs_g']) ?? 0,
        fatG: readDouble(map['fat_g']) ?? 0,
        createdAt: readDate(map['created_at']),
      );
}

class WaterEntry {
  const WaterEntry({required this.id, required this.day, required this.amountMl, this.createdAt});

  final String id;
  final String day;
  final int amountMl;
  final DateTime? createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'day': day,
        'amount_ml': amountMl,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory WaterEntry.fromMap(Map<String, Object?> map) => WaterEntry(
        id: map['id']! as String,
        day: readString(map['day']) ?? '',
        amountMl: readInt(map['amount_ml']) ?? 0,
        createdAt: readDate(map['created_at']),
      );
}

class NutritionTotals {
  const NutritionTotals({this.calories = 0, this.proteinG = 0, this.carbsG = 0, this.fatG = 0});

  factory NutritionTotals.of(Iterable<FoodEntry> entries) {
    var calories = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0;
    for (final entry in entries) {
      calories += entry.calories;
      protein += entry.proteinG;
      carbs += entry.carbsG;
      fat += entry.fatG;
    }
    return NutritionTotals(calories: calories, proteinG: protein, carbsG: carbs, fatG: fat);
  }

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
}

class NutritionTargets {
  const NutritionTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterMl,
  });

  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int waterMl;
}

/// Daily targets from Mifflin-St Jeor BMR, an activity factor based on
/// training days, and a goal adjustment. These are rough guides, not
/// medical advice.
class NutritionCalculator {
  const NutritionCalculator._();

  static const int minimumCalories = 1200;

  static double bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required Sex sex,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return switch (sex) {
      Sex.male => base + 5,
      Sex.female => base - 161,
      Sex.unspecified => base - 78,
    };
  }

  static double activityFactor(int trainingDaysPerWeek) {
    if (trainingDaysPerWeek <= 1) return 1.2;
    if (trainingDaysPerWeek <= 3) return 1.375;
    if (trainingDaysPerWeek <= 5) return 1.55;
    return 1.725;
  }

  static int goalAdjustment(FitnessGoal goal) => switch (goal) {
        FitnessGoal.weightLoss => -500,
        FitnessGoal.muscleGain => 300,
        FitnessGoal.endurance => 100,
        FitnessGoal.generalHealth => 0,
      };

  static double proteinPerKg(FitnessGoal goal) => switch (goal) {
        FitnessGoal.muscleGain => 2.0,
        FitnessGoal.weightLoss => 2.0,
        FitnessGoal.endurance => 1.6,
        FitnessGoal.generalHealth => 1.4,
      };

  /// 35 ml per kg, rounded to a 250 ml glass, at least 1.5 l.
  static int waterGoalMl(double weightKg) => max(1500, ((weightKg * 35) / 250).round() * 250);

  static NutritionTargets targets(
    UserProfile profile, {
    int calorieOverride = 0,
    int waterOverride = 0,
  }) {
    final tdee = bmr(
          weightKg: profile.weightKg,
          heightCm: profile.heightCm,
          age: profile.age,
          sex: profile.sex,
        ) *
        activityFactor(profile.daysPerWeek);
    final calories = calorieOverride > 0
        ? calorieOverride
        : max(minimumCalories, (tdee + goalAdjustment(profile.goal)).round());
    final protein = (proteinPerKg(profile.goal) * profile.weightKg).round();
    final fat = (calories * 0.25 / 9).round();
    final carbs = max(0, ((calories - protein * 4 - fat * 9) / 4).round());
    return NutritionTargets(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      waterMl: waterOverride > 0 ? waterOverride : waterGoalMl(profile.weightKg),
    );
  }
}

abstract interface class NutritionRepository {
  Future<List<FoodEntry>> foodForDay(String day);

  Future<void> saveFood(FoodEntry entry);

  Future<void> deleteFood(String id);

  Future<List<WaterEntry>> waterForDay(String day);

  Future<void> saveWater(WaterEntry entry);

  Future<void> deleteWater(String id);
}
