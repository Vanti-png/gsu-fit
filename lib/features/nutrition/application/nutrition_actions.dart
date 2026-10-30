import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/features/nutrition/application/nutrition_providers.dart';
import 'package:gsu_fit/features/nutrition/domain/nutrition.dart';

final nutritionActionsProvider = Provider<NutritionActions>((ref) => NutritionActions(ref));

class NutritionActions {
  NutritionActions(this._ref);

  final Ref _ref;

  NutritionRepository get _repository => _ref.read(nutritionRepositoryProvider);

  Future<WaterEntry> addWater(String day, int amountMl) async {
    final entry = WaterEntry(id: newId(), day: day, amountMl: amountMl);
    await _repository.saveWater(entry);
    _ref.invalidate(waterEntriesProvider(day));
    return entry;
  }

  Future<void> deleteWater(WaterEntry entry) async {
    await _repository.deleteWater(entry.id);
    _ref.invalidate(waterEntriesProvider(entry.day));
  }

  Future<void> saveFood(FoodEntry entry) async {
    await _repository.saveFood(entry);
    _ref.invalidate(foodEntriesProvider(entry.day));
  }

  Future<void> deleteFood(FoodEntry entry) async {
    await _repository.deleteFood(entry.id);
    _ref.invalidate(foodEntriesProvider(entry.day));
  }
}
