import 'package:gsu_fit/core/utils/map_read.dart';
import 'package:gsu_fit/core/utils/units.dart';

enum AppThemeMode { system, light, dark }

/// Low: first image frame only and the small video version when one exists.
enum MediaQuality { low, high }

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.weightUnit = WeightUnit.kg,
    this.mediaQuality = MediaQuality.low,
    this.mediaOnDemand = false,
    this.workoutReminderEnabled = false,
    this.workoutReminderDays = const [1, 3, 5],
    this.workoutReminderMinutes = 18 * 60,
    this.waterReminderEnabled = false,
    this.waterReminderIntervalHours = 2,
    this.waterReminderStartHour = 9,
    this.waterReminderEndHour = 21,
    this.measurementReminderEnabled = false,
    this.measurementReminderDay = 1,
    this.measurementReminderMinutes = 9 * 60,
    this.waterGoalMl = 0,
    this.calorieGoal = 0,
    this.stepGoal = 8000,
    this.stepsEnabled = false,
    this.defaultRestSeconds = 90,
  });

  final AppThemeMode themeMode;
  final WeightUnit weightUnit;
  final MediaQuality mediaQuality;

  /// When true, images and videos are only downloaded after a tap.
  final bool mediaOnDemand;

  final bool workoutReminderEnabled;

  /// 1 = Monday … 7 = Sunday.
  final List<int> workoutReminderDays;

  /// Minutes after midnight.
  final int workoutReminderMinutes;

  final bool waterReminderEnabled;
  final int waterReminderIntervalHours;
  final int waterReminderStartHour;
  final int waterReminderEndHour;

  final bool measurementReminderEnabled;
  final int measurementReminderDay;
  final int measurementReminderMinutes;

  /// 0 means "calculate from the profile".
  final int waterGoalMl;
  final int calorieGoal;
  final int stepGoal;
  final bool stepsEnabled;
  final int defaultRestSeconds;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    WeightUnit? weightUnit,
    MediaQuality? mediaQuality,
    bool? mediaOnDemand,
    bool? workoutReminderEnabled,
    List<int>? workoutReminderDays,
    int? workoutReminderMinutes,
    bool? waterReminderEnabled,
    int? waterReminderIntervalHours,
    int? waterReminderStartHour,
    int? waterReminderEndHour,
    bool? measurementReminderEnabled,
    int? measurementReminderDay,
    int? measurementReminderMinutes,
    int? waterGoalMl,
    int? calorieGoal,
    int? stepGoal,
    bool? stepsEnabled,
    int? defaultRestSeconds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      weightUnit: weightUnit ?? this.weightUnit,
      mediaQuality: mediaQuality ?? this.mediaQuality,
      mediaOnDemand: mediaOnDemand ?? this.mediaOnDemand,
      workoutReminderEnabled: workoutReminderEnabled ?? this.workoutReminderEnabled,
      workoutReminderDays: workoutReminderDays ?? this.workoutReminderDays,
      workoutReminderMinutes: workoutReminderMinutes ?? this.workoutReminderMinutes,
      waterReminderEnabled: waterReminderEnabled ?? this.waterReminderEnabled,
      waterReminderIntervalHours: waterReminderIntervalHours ?? this.waterReminderIntervalHours,
      waterReminderStartHour: waterReminderStartHour ?? this.waterReminderStartHour,
      waterReminderEndHour: waterReminderEndHour ?? this.waterReminderEndHour,
      measurementReminderEnabled: measurementReminderEnabled ?? this.measurementReminderEnabled,
      measurementReminderDay: measurementReminderDay ?? this.measurementReminderDay,
      measurementReminderMinutes: measurementReminderMinutes ?? this.measurementReminderMinutes,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      stepGoal: stepGoal ?? this.stepGoal,
      stepsEnabled: stepsEnabled ?? this.stepsEnabled,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
    );
  }

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'weightUnit': weightUnit.name,
        'mediaQuality': mediaQuality.name,
        'mediaOnDemand': mediaOnDemand,
        'workoutReminderEnabled': workoutReminderEnabled,
        'workoutReminderDays': workoutReminderDays,
        'workoutReminderMinutes': workoutReminderMinutes,
        'waterReminderEnabled': waterReminderEnabled,
        'waterReminderIntervalHours': waterReminderIntervalHours,
        'waterReminderStartHour': waterReminderStartHour,
        'waterReminderEndHour': waterReminderEndHour,
        'measurementReminderEnabled': measurementReminderEnabled,
        'measurementReminderDay': measurementReminderDay,
        'measurementReminderMinutes': measurementReminderMinutes,
        'waterGoalMl': waterGoalMl,
        'calorieGoal': calorieGoal,
        'stepGoal': stepGoal,
        'stepsEnabled': stepsEnabled,
        'defaultRestSeconds': defaultRestSeconds,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    const defaults = AppSettings();
    final days = json['workoutReminderDays'];
    return AppSettings(
      themeMode: readEnum(AppThemeMode.values, json['themeMode'], defaults.themeMode),
      weightUnit: readEnum(WeightUnit.values, json['weightUnit'], defaults.weightUnit),
      mediaQuality: readEnum(MediaQuality.values, json['mediaQuality'], defaults.mediaQuality),
      mediaOnDemand: readBool(json['mediaOnDemand']),
      workoutReminderEnabled: readBool(json['workoutReminderEnabled']),
      workoutReminderDays: days is List
          ? days.map(readInt).whereType<int>().where((d) => d >= 1 && d <= 7).toList()
          : defaults.workoutReminderDays,
      workoutReminderMinutes:
          readInt(json['workoutReminderMinutes']) ?? defaults.workoutReminderMinutes,
      waterReminderEnabled: readBool(json['waterReminderEnabled']),
      waterReminderIntervalHours:
          readInt(json['waterReminderIntervalHours']) ?? defaults.waterReminderIntervalHours,
      waterReminderStartHour:
          readInt(json['waterReminderStartHour']) ?? defaults.waterReminderStartHour,
      waterReminderEndHour: readInt(json['waterReminderEndHour']) ?? defaults.waterReminderEndHour,
      measurementReminderEnabled: readBool(json['measurementReminderEnabled']),
      measurementReminderDay:
          readInt(json['measurementReminderDay']) ?? defaults.measurementReminderDay,
      measurementReminderMinutes:
          readInt(json['measurementReminderMinutes']) ?? defaults.measurementReminderMinutes,
      waterGoalMl: readInt(json['waterGoalMl']) ?? defaults.waterGoalMl,
      calorieGoal: readInt(json['calorieGoal']) ?? defaults.calorieGoal,
      stepGoal: readInt(json['stepGoal']) ?? defaults.stepGoal,
      stepsEnabled: readBool(json['stepsEnabled']),
      defaultRestSeconds: readInt(json['defaultRestSeconds']) ?? defaults.defaultRestSeconds,
    );
  }
}

abstract interface class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);

  Future<String?> getValue(String key);

  Future<void> setValue(String key, String value);
}
