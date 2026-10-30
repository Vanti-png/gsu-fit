import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/platform/native_bridge.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/settings/data/sqlite_settings_repository.dart';
import 'package:gsu_fit/features/settings/data/web_settings_repository.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';

/// Loaded in main() so the first frame already has the right theme.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => kIsWeb
      ? WebSettingsRepository(ref.watch(jsonStoreProvider))
      : SqliteSettingsRepository(ref.watch(appDatabaseProvider)),
);

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> change(AppSettings Function(AppSettings current) update) async {
    state = update(state);
    await ref.read(settingsRepositoryProvider).save(state);
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(ref.watch(reminderBridgeProvider)),
);

/// Turns the reminder settings into native alarms.
class ReminderScheduler {
  ReminderScheduler(this._bridge);

  final ReminderBridge _bridge;

  static const int workoutBaseId = 100;
  static const int waterBaseId = 200;
  static const int measurementId = 300;
  static const int restTimerId = 900;

  static bool anyEnabled(AppSettings settings) =>
      settings.workoutReminderEnabled ||
      settings.waterReminderEnabled ||
      settings.measurementReminderEnabled;

  Future<bool> requestPermission() => _bridge.requestPermission();

  /// Replaces every scheduled reminder with what [settings] asks for.
  Future<void> apply(AppSettings settings, AppLocalizations l) async {
    await _bridge.cancelAll();

    if (settings.workoutReminderEnabled) {
      for (final day in settings.workoutReminderDays) {
        await _bridge.scheduleRepeating(
          id: workoutBaseId + day,
          title: l.reminderWorkoutTitle,
          body: l.reminderWorkoutBody,
          hour: settings.workoutReminderMinutes ~/ 60,
          minute: settings.workoutReminderMinutes % 60,
          weekdays: [day],
        );
      }
    }

    if (settings.waterReminderEnabled) {
      final interval = max(1, settings.waterReminderIntervalHours);
      for (var hour = settings.waterReminderStartHour;
          hour <= settings.waterReminderEndHour;
          hour += interval) {
        await _bridge.scheduleRepeating(
          id: waterBaseId + hour,
          title: l.reminderWaterTitle,
          body: l.reminderWaterBody,
          hour: hour,
          minute: 0,
        );
      }
    }

    if (settings.measurementReminderEnabled) {
      await _bridge.scheduleRepeating(
        id: measurementId,
        title: l.reminderMeasurementTitle,
        body: l.reminderMeasurementBody,
        hour: settings.measurementReminderMinutes ~/ 60,
        minute: settings.measurementReminderMinutes % 60,
        weekdays: [settings.measurementReminderDay],
      );
    }
  }
}
