import 'package:gsu_fit/core/utils/map_read.dart';
import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/features/nutrition/domain/nutrition.dart';

class WebNutritionRepository implements NutritionRepository {
  WebNutritionRepository(this._store);

  final JsonStore _store;

  static const String _food = 'food_entries';
  static const String _water = 'water_entries';

  List<Map<String, Object?>> _forDay(String table, String day) => _store
      .rows(table)
      .where((row) => row['day'] == day)
      .toList()
    ..sort((a, b) => (readInt(a['created_at']) ?? 0).compareTo(readInt(b['created_at']) ?? 0));

  @override
  Future<List<FoodEntry>> foodForDay(String day) async =>
      _forDay(_food, day).map(FoodEntry.fromMap).toList();

  @override
  Future<void> saveFood(FoodEntry entry) async => _store.upsert(_food, entry.toMap());

  @override
  Future<void> deleteFood(String id) async => _store.softDelete(_food, (row) => row['id'] == id);

  @override
  Future<List<WaterEntry>> waterForDay(String day) async =>
      _forDay(_water, day).map(WaterEntry.fromMap).toList();

  @override
  Future<void> saveWater(WaterEntry entry) async => _store.upsert(_water, entry.toMap());

  @override
  Future<void> deleteWater(String id) async => _store.softDelete(_water, (row) => row['id'] == id);
}
