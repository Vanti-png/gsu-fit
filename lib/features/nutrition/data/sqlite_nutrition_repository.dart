import 'package:gsu_fit/core/database/sqlite_store.dart';
import 'package:gsu_fit/features/nutrition/domain/nutrition.dart';

class SqliteNutritionRepository extends SqliteStore implements NutritionRepository {
  SqliteNutritionRepository(super.database);

  static const String _food = 'food_entries';
  static const String _water = 'water_entries';

  @override
  Future<List<FoodEntry>> foodForDay(String day) async {
    final rows = await queryActive(_food, where: 'day = ?', whereArgs: [day], orderBy: 'created_at');
    return rows.map(FoodEntry.fromMap).toList();
  }

  @override
  Future<void> saveFood(FoodEntry entry) => upsertRow(_food, entry.toMap());

  @override
  Future<void> deleteFood(String id) => softDelete(_food, where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<WaterEntry>> waterForDay(String day) async {
    final rows =
        await queryActive(_water, where: 'day = ?', whereArgs: [day], orderBy: 'created_at');
    return rows.map(WaterEntry.fromMap).toList();
  }

  @override
  Future<void> saveWater(WaterEntry entry) => upsertRow(_water, entry.toMap());

  @override
  Future<void> deleteWater(String id) => softDelete(_water, where: 'id = ?', whereArgs: [id]);
}
