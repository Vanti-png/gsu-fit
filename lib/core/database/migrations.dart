/// Schema migrations, keyed by the version they upgrade to.
///
/// Every synced table carries `created_at`, `updated_at` and `deleted_at`
/// (epoch milliseconds). Rows are never hard-deleted by normal use, so a
/// future sync service can push "everything with updated_at > last sync"
/// including deletions. Primary keys are UUID strings for the same reason.
library;

/// Column names per table, read from the CREATE TABLE statements below so
/// the web store (which has no SQL) validates imports against the same
/// schema as SQLite.
Map<String, List<String>> schemaColumns() {
  final tables = <String, List<String>>{};
  final create = RegExp(r'^CREATE TABLE (\w+)\s*\(([\s\S]*)\)$');
  final addColumn = RegExp(r'^ALTER TABLE (\w+) ADD COLUMN (\w+)');
  final versions = migrations.keys.toList()..sort();
  for (final version in versions) {
    for (final statement in migrations[version]!) {
      final sql = statement.trim();
      final table = create.firstMatch(sql);
      if (table != null) {
        tables[table.group(1)!] = [
          for (final column in table.group(2)!.split(','))
            if (column.trim().isNotEmpty) column.trim().split(RegExp(r'\s+')).first,
        ];
        continue;
      }
      final added = addColumn.firstMatch(sql);
      if (added != null) tables[added.group(1)!]?.add(added.group(2)!);
    }
  }
  return tables;
}

const String _syncColumns =
    'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER';

const Map<int, List<String>> migrations = {
  1: [
    'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    '''
    CREATE TABLE profile (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL DEFAULT '',
      age INTEGER NOT NULL,
      height_cm REAL NOT NULL,
      weight_kg REAL NOT NULL,
      sex TEXT NOT NULL,
      goal TEXT NOT NULL,
      experience TEXT NOT NULL,
      days_per_week INTEGER NOT NULL,
      $_syncColumns
    )''',
    '''
    CREATE TABLE exercises (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      primary_muscles TEXT NOT NULL DEFAULT '',
      secondary_muscles TEXT NOT NULL DEFAULT '',
      equipment TEXT NOT NULL,
      instructions TEXT NOT NULL DEFAULT '',
      image_urls TEXT NOT NULL DEFAULT '',
      video_url TEXT,
      video_url_low TEXT,
      is_timed INTEGER NOT NULL DEFAULT 0,
      is_custom INTEGER NOT NULL DEFAULT 0,
      $_syncColumns
    )''',
    '''
    CREATE TABLE programs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      split TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 0,
      duration_weeks INTEGER NOT NULL DEFAULT 8,
      start_date INTEGER NOT NULL,
      $_syncColumns
    )''',
    '''
    CREATE TABLE program_days (
      id TEXT PRIMARY KEY,
      program_id TEXT NOT NULL,
      name TEXT NOT NULL,
      position INTEGER NOT NULL,
      $_syncColumns
    )''',
    '''
    CREATE TABLE program_exercises (
      id TEXT PRIMARY KEY,
      day_id TEXT NOT NULL,
      exercise_id TEXT NOT NULL,
      position INTEGER NOT NULL,
      sets INTEGER NOT NULL,
      min_reps INTEGER NOT NULL,
      max_reps INTEGER NOT NULL,
      rest_seconds INTEGER NOT NULL,
      start_weight_kg REAL NOT NULL DEFAULT 0,
      increment_kg REAL NOT NULL DEFAULT 2.5,
      $_syncColumns
    )''',
    '''
    CREATE TABLE workouts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      program_id TEXT,
      program_day_id TEXT,
      started_at INTEGER NOT NULL,
      ended_at INTEGER,
      duration_seconds INTEGER NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '',
      $_syncColumns
    )''',
    '''
    CREATE TABLE workout_sets (
      id TEXT PRIMARY KEY,
      workout_id TEXT NOT NULL,
      exercise_id TEXT NOT NULL,
      exercise_order INTEGER NOT NULL,
      set_index INTEGER NOT NULL,
      reps INTEGER NOT NULL DEFAULT 0,
      weight_kg REAL NOT NULL DEFAULT 0,
      completed INTEGER NOT NULL DEFAULT 0,
      target_reps INTEGER,
      rest_seconds INTEGER NOT NULL DEFAULT 90,
      $_syncColumns
    )''',
    '''
    CREATE TABLE cardio_sessions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      started_at INTEGER NOT NULL,
      duration_seconds INTEGER NOT NULL,
      distance_km REAL,
      calories REAL NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '',
      $_syncColumns
    )''',
    '''
    CREATE TABLE body_measurements (
      id TEXT PRIMARY KEY,
      date INTEGER NOT NULL,
      weight_kg REAL,
      height_cm REAL,
      body_fat_percent REAL,
      chest_cm REAL,
      waist_cm REAL,
      arm_cm REAL,
      leg_cm REAL,
      notes TEXT NOT NULL DEFAULT '',
      $_syncColumns
    )''',
    '''
    CREATE TABLE progress_photos (
      id TEXT PRIMARY KEY,
      date INTEGER NOT NULL,
      file_path TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      $_syncColumns
    )''',
    '''
    CREATE TABLE food_entries (
      id TEXT PRIMARY KEY,
      day TEXT NOT NULL,
      meal TEXT NOT NULL,
      name TEXT NOT NULL,
      calories REAL NOT NULL DEFAULT 0,
      protein_g REAL NOT NULL DEFAULT 0,
      carbs_g REAL NOT NULL DEFAULT 0,
      fat_g REAL NOT NULL DEFAULT 0,
      $_syncColumns
    )''',
    '''
    CREATE TABLE water_entries (
      id TEXT PRIMARY KEY,
      day TEXT NOT NULL,
      amount_ml INTEGER NOT NULL,
      $_syncColumns
    )''',
    'CREATE INDEX idx_program_days_program ON program_days (program_id)',
    'CREATE INDEX idx_program_exercises_day ON program_exercises (day_id)',
    'CREATE INDEX idx_workouts_started ON workouts (started_at)',
    'CREATE INDEX idx_workout_sets_workout ON workout_sets (workout_id)',
    'CREATE INDEX idx_workout_sets_exercise ON workout_sets (exercise_id)',
    'CREATE INDEX idx_cardio_started ON cardio_sessions (started_at)',
    'CREATE INDEX idx_measurements_date ON body_measurements (date)',
    'CREATE INDEX idx_food_day ON food_entries (day)',
    'CREATE INDEX idx_water_day ON water_entries (day)',
  ],
};
