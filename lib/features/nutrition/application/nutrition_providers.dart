import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/nutrition/data/sqlite_nutrition_repository.dart';
import 'package:gsu_fit/features/nutrition/domain/nutrition.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => SqliteNutritionRepository(ref.watch(appDatabaseProvider)),
);

/// Keyed by dayKey().
final foodEntriesProvider = FutureProvider.family<List<FoodEntry>, String>(
  (ref, day) => ref.watch(nutritionRepositoryProvider).foodForDay(day),
);

final waterEntriesProvider = FutureProvider.family<List<WaterEntry>, String>(
  (ref, day) => ref.watch(nutritionRepositoryProvider).waterForDay(day),
);

/// Null until a profile exists.
final nutritionTargetsProvider = Provider<NutritionTargets?>((ref) {
  final profile = ref.watch(profileProvider).dataOrNull;
  if (profile == null) return null;
  final settings = ref.watch(settingsProvider);
  return NutritionCalculator.targets(
    profile,
    calorieOverride: settings.calorieGoal,
    waterOverride: settings.waterGoalMl,
  );
});
