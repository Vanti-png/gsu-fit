import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/body/application/body_providers.dart';
import 'package:gsu_fit/features/cardio/application/cardio_providers.dart';
import 'package:gsu_fit/features/data_transfer/data/data_transfer_service.dart';
import 'package:gsu_fit/features/data_transfer/data/table_access.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/nutrition/application/nutrition_providers.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/programs/application/program_providers.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';
import 'package:gsu_fit/features/workout/application/active_workout_controller.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/seed/seed_service.dart';

final dataTransferServiceProvider = Provider<DataTransferService>(
  (ref) => DataTransferService(
    kIsWeb
        ? JsonTableAccess(ref.watch(jsonStoreProvider))
        : SqliteTableAccess(ref.watch(appDatabaseProvider)),
  ),
);

/// Reloads every data provider after an import or a reset.
void invalidateAllData(WidgetRef ref) {
  ref.invalidate(profileProvider);
  ref.invalidate(exercisesProvider);
  ref.invalidate(programsProvider);
  ref.invalidate(workoutsProvider);
  ref.invalidate(unfinishedWorkoutProvider);
  ref.invalidate(cardioSessionsProvider);
  ref.invalidate(measurementsProvider);
  ref.invalidate(photosProvider);
  ref.invalidate(foodEntriesProvider);
  ref.invalidate(waterEntriesProvider);
}

String tableLabel(AppLocalizations l, String table) => switch (table) {
      'workouts' => l.tableWorkouts,
      'workout_sets' => l.tableWorkoutSets,
      'cardio_sessions' => l.tableCardio,
      'body_measurements' => l.tableMeasurements,
      'food_entries' => l.tableFood,
      'water_entries' => l.tableWater,
      'exercises' => l.tableExercises,
      'programs' => l.tablePrograms,
      'program_days' => l.tableProgramDays,
      'program_exercises' => l.tableProgramExercises,
      'profile' => l.tableProfile,
      _ => table,
    };

Future<String?> _chooseTable(BuildContext context, String title) {
  final l = context.l10n;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final table in DataTransferService.csvTables)
            ListTile(
              title: Text(tableLabel(l, table)),
              onTap: () => Navigator.of(context).pop(table),
            ),
        ],
      ),
    ),
  );
}

Future<void> exportJsonBackup(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  try {
    final json = await ref.read(dataTransferServiceProvider).exportJson();
    final saved = await ref.read(fileBridgeProvider).saveDocument(
          fileName: 'gsu_fit_yedek_${dayKey(DateTime.now())}.json',
          mimeType: 'application/json',
          bytes: Uint8List.fromList(utf8.encode(json)),
        );
    if (context.mounted) showMessage(context, saved ? l.dataExported : l.dataCancelled);
  } catch (_) {
    if (context.mounted) showMessage(context, l.dataExportFailed);
  }
}

Future<void> exportCsvTable(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final table = await _chooseTable(context, l.dataExportCsvChoose);
  if (table == null || !context.mounted) return;
  try {
    final csv = await ref.read(dataTransferServiceProvider).exportCsv(table);
    final saved = await ref.read(fileBridgeProvider).saveDocument(
          fileName: 'gsu_fit_${table}_${dayKey(DateTime.now())}.csv',
          mimeType: 'text/csv',
          bytes: Uint8List.fromList(utf8.encode(csv)),
        );
    if (context.mounted) showMessage(context, saved ? l.dataExported : l.dataCancelled);
  } catch (_) {
    if (context.mounted) showMessage(context, l.dataExportFailed);
  }
}

/// Imports a .json backup or a .csv table chosen in the system picker.
Future<void> importData(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  try {
    final document = await ref.read(fileBridgeProvider).openDocument();
    if (document == null || !context.mounted) return;
    final content = utf8.decode(document.bytes, allowMalformed: true);
    final service = ref.read(dataTransferServiceProvider);
    final ImportReport report;
    if (document.name.toLowerCase().endsWith('.csv')) {
      final table = DataTransferService.tableFromFileName(document.name) ??
          await _chooseTable(context, l.dataImportCsvChoose);
      if (table == null) return;
      report = await service.importCsv(table, content);
    } else {
      report = await service.importJson(content);
    }
    invalidateAllData(ref);
    if (context.mounted) {
      showMessage(context, l.dataImported('${report.imported}', '${report.skipped}'));
    }
  } on ImportFormatException catch (error) {
    if (!context.mounted) return;
    showMessage(
      context,
      error.reason == 'newer_version' ? l.dataImportNewer : l.dataImportInvalid,
    );
  } catch (_) {
    if (context.mounted) showMessage(context, l.dataImportFailed);
  }
}

/// Deletes all rows, photos, cached media and reminders, then reinstalls
/// the seed data. The app returns to onboarding.
Future<void> wipeAllData(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final ok = await confirmDialog(
    context,
    title: l.dataWipeTitle,
    message: l.dataWipeMessage,
    confirmLabel: l.dataWipeConfirm,
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  final navigator = Navigator.of(context);
  try {
    if (ref.read(activeWorkoutProvider) != null) {
      await ref.read(activeWorkoutProvider.notifier).discard();
    }
    await ref.read(dataTransferServiceProvider).wipe();
    if (!kIsWeb) {
      await ref.read(photoStorageProvider).removeAll();
      await ref.read(mediaCacheProvider).clear();
      await ref.read(reminderBridgeProvider).cancelAll();
    }
    await ref.read(settingsProvider.notifier).change((_) => const AppSettings());
    await SeedService(
      settings: ref.read(settingsRepositoryProvider),
      exercises: ref.read(exerciseRepositoryProvider),
      programs: ref.read(programRepositoryProvider),
    ).seedIfNeeded(l);
    // Invalidate before popping: this ref belongs to the settings screen.
    invalidateAllData(ref);
    navigator.popUntil((route) => route.isFirst);
  } catch (_) {
    if (context.mounted) showMessage(context, l.dataWipeFailed);
  }
}
