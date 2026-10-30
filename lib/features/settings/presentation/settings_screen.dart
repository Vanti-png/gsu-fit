import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/dates.dart' show formatMinutesOfDay;
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/data_transfer/application/data_transfer_actions.dart';
import 'package:gsu_fit/features/nutrition/application/nutrition_providers.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/profile/presentation/edit_profile_screen.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';
import 'package:gsu_fit/features/steps/application/steps_providers.dart';
import 'package:gsu_fit/features/steps/presentation/steps_card.dart';

void openSettings(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Future<int> _cacheSize = ref.read(mediaCacheProvider).sizeInBytes();

  SettingsController get _settings => ref.read(settingsProvider.notifier);

  Future<void> _change(AppSettings Function(AppSettings s) update) => _settings.change(update);

  /// Saves reminder settings and reschedules; asks for the notification
  /// permission the first time a reminder is switched on.
  Future<void> _changeReminders(AppSettings Function(AppSettings s) update) async {
    final l = context.l10n;
    final next = update(ref.read(settingsProvider));
    final scheduler = ref.read(reminderSchedulerProvider);
    if (ReminderScheduler.anyEnabled(next)) {
      final allowed = await scheduler.requestPermission();
      if (!allowed) {
        if (mounted) showMessage(context, l.reminderPermissionDenied);
        return;
      }
    }
    await _change((_) => next);
    await scheduler.apply(next, l);
  }

  Future<int?> _askNumber({
    required String title,
    required int initial,
    required String suffix,
    String? helper,
  }) async {
    final l = context.l10n;
    final controller = TextEditingController(text: initial == 0 ? '' : '$initial');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: fieldDecoration(title, suffix: suffix, helper: helper),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(parseInt(controller.text) ?? 0),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<int?> _pickTime(int minutes) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );

  Widget _weekdayChips(Set<int> selected, ValueChanged<int> onTap) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var day = 1; day <= 7; day++)
            FilterChip(
              label: Text(l.weekdayShort(day)),
              tooltip: l.weekdayLong(day),
              selected: selected.contains(day),
              onSelected: (_) => onTap(day),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final profile = ref.watch(profileProvider).dataOrNull;
    final targets = ref.watch(nutritionTargetsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (profile != null)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(profile.name.isEmpty ? l.profileTitle : profile.name),
              subtitle: Text('${l.goal(profile.goal)} · ${l.level(profile.experience)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => EditProfileScreen(profile: profile)),
              ),
            ),

          _header(l.settingsAppearance),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AppThemeMode>(
              segments: [
                for (final mode in AppThemeMode.values)
                  ButtonSegment(value: mode, label: Text(l.themeMode(mode))),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (value) => _change((c) => c.copyWith(themeMode: value.first)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<WeightUnit>(
              segments: [
                ButtonSegment(value: WeightUnit.kg, label: Text(l.unitKg)),
                ButtonSegment(value: WeightUnit.lb, label: Text(l.unitLb)),
              ],
              selected: {s.weightUnit},
              onSelectionChanged: (value) => _change((c) => c.copyWith(weightUnit: value.first)),
            ),
          ),

          _header(l.settingsWorkout),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l.settingsDefaultRest),
            subtitle: Text(l.secondsValue('${s.defaultRestSeconds}')),
            onTap: () async {
              final value = await _askNumber(
                title: l.settingsDefaultRest,
                initial: s.defaultRestSeconds,
                suffix: l.unitSecondsShort,
              );
              if (value != null && value > 0) {
                await _change((c) => c.copyWith(defaultRestSeconds: value.clamp(10, 600)));
              }
            },
          ),

          _header(l.settingsReminders),
          SwitchListTile(
            secondary: const Icon(Icons.fitness_center),
            title: Text(l.reminderWorkout),
            subtitle: Text(l.reminderWorkoutHint),
            value: s.workoutReminderEnabled,
            onChanged: (value) => _changeReminders((c) => c.copyWith(workoutReminderEnabled: value)),
          ),
          if (s.workoutReminderEnabled) ...[
            _weekdayChips(s.workoutReminderDays.toSet(), (day) {
              final days = s.workoutReminderDays.toSet();
              if (!days.remove(day)) days.add(day);
              _changeReminders((c) => c.copyWith(workoutReminderDays: days.toList()..sort()));
            }),
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(l.reminderTime),
              trailing: Text(formatMinutesOfDay(s.workoutReminderMinutes)),
              onTap: () async {
                final minutes = await _pickTime(s.workoutReminderMinutes);
                if (minutes != null) {
                  await _changeReminders((c) => c.copyWith(workoutReminderMinutes: minutes));
                }
              },
            ),
          ],
          SwitchListTile(
            secondary: const Icon(Icons.water_drop_outlined),
            title: Text(l.reminderWater),
            subtitle: Text(l.reminderWaterHint(
              '${s.waterReminderIntervalHours}',
              '${s.waterReminderStartHour}',
              '${s.waterReminderEndHour}',
            )),
            value: s.waterReminderEnabled,
            onChanged: (value) => _changeReminders((c) => c.copyWith(waterReminderEnabled: value)),
          ),
          if (s.waterReminderEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final hours in const [1, 2, 3, 4])
                    ChoiceChip(
                      label: Text(l.reminderEveryHours('$hours')),
                      selected: s.waterReminderIntervalHours == hours,
                      onSelected: (_) =>
                          _changeReminders((c) => c.copyWith(waterReminderIntervalHours: hours)),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(l.reminderStartHour),
              trailing: Text(formatMinutesOfDay(s.waterReminderStartHour * 60)),
              onTap: () async {
                final minutes = await _pickTime(s.waterReminderStartHour * 60);
                if (minutes == null) return;
                final hour = minutes ~/ 60;
                await _changeReminders((c) => c.copyWith(
                      waterReminderStartHour: hour,
                      waterReminderEndHour: c.waterReminderEndHour < hour ? hour : c.waterReminderEndHour,
                    ));
              },
            ),
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(l.reminderEndHour),
              trailing: Text(formatMinutesOfDay(s.waterReminderEndHour * 60)),
              onTap: () async {
                final minutes = await _pickTime(s.waterReminderEndHour * 60);
                if (minutes == null) return;
                final hour = minutes ~/ 60;
                await _changeReminders((c) => c.copyWith(
                      waterReminderEndHour: hour,
                      waterReminderStartHour: c.waterReminderStartHour > hour ? hour : c.waterReminderStartHour,
                    ));
              },
            ),
          ],
          SwitchListTile(
            secondary: const Icon(Icons.straighten),
            title: Text(l.reminderMeasurement),
            subtitle: Text(l.reminderMeasurementHint),
            value: s.measurementReminderEnabled,
            onChanged: (value) =>
                _changeReminders((c) => c.copyWith(measurementReminderEnabled: value)),
          ),
          if (s.measurementReminderEnabled) ...[
            _weekdayChips({s.measurementReminderDay}, (day) {
              _changeReminders((c) => c.copyWith(measurementReminderDay: day));
            }),
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(l.reminderTime),
              trailing: Text(formatMinutesOfDay(s.measurementReminderMinutes)),
              onTap: () async {
                final minutes = await _pickTime(s.measurementReminderMinutes);
                if (minutes != null) {
                  await _changeReminders((c) => c.copyWith(measurementReminderMinutes: minutes));
                }
              },
            ),
          ],

          _header(l.settingsGoals),
          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: Text(l.goalWater),
            subtitle: Text(s.waterGoalMl > 0
                ? '${formatNumber(s.waterGoalMl, decimals: 0)} ml'
                : l.goalAuto('${formatNumber(targets?.waterMl ?? 0, decimals: 0)} ml')),
            onTap: () async {
              final value = await _askNumber(
                title: l.goalWater,
                initial: s.waterGoalMl,
                suffix: 'ml',
                helper: l.goalAutoHint,
              );
              if (value != null) await _change((c) => c.copyWith(waterGoalMl: value.clamp(0, 10000)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: Text(l.goalCalories),
            subtitle: Text(s.calorieGoal > 0
                ? l.kcalValue(formatNumber(s.calorieGoal, decimals: 0))
                : l.goalAuto(l.kcalValue(formatNumber(targets?.calories ?? 0, decimals: 0)))),
            onTap: () async {
              final value = await _askNumber(
                title: l.goalCalories,
                initial: s.calorieGoal,
                suffix: 'kcal',
                helper: l.goalAutoHint,
              );
              if (value != null) await _change((c) => c.copyWith(calorieGoal: value.clamp(0, 10000)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_walk),
            title: Text(l.goalSteps),
            subtitle: Text(formatNumber(s.stepGoal, decimals: 0)),
            onTap: () async {
              final value = await _askNumber(
                title: l.goalSteps,
                initial: s.stepGoal,
                suffix: l.stepsUnit,
              );
              if (value != null && value > 0) {
                await _change((c) => c.copyWith(stepGoal: value.clamp(100, 100000)));
              }
            },
          ),

          _header(l.settingsHealth),
          SwitchListTile(
            secondary: const Icon(Icons.monitor_heart_outlined),
            title: Text(l.stepsSetting),
            subtitle: Text(l.stepsSettingHint),
            value: s.stepsEnabled,
            onChanged: (value) async {
              if (value) {
                await enableSteps(context, ref);
              } else {
                await _change((c) => c.copyWith(stepsEnabled: false));
                ref.invalidate(todayStepsProvider);
              }
            },
          ),

          _header(l.settingsMedia),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<MediaQuality>(
              segments: [
                ButtonSegment(value: MediaQuality.low, label: Text(l.mediaQualityLow)),
                ButtonSegment(value: MediaQuality.high, label: Text(l.mediaQualityHigh)),
              ],
              selected: {s.mediaQuality},
              onSelectionChanged: (value) => _change((c) => c.copyWith(mediaQuality: value.first)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l.mediaQualityHint, style: Theme.of(context).textTheme.bodySmall),
          ),
          SwitchListTile(
            title: Text(l.mediaOnDemand),
            subtitle: Text(l.mediaOnDemandHint),
            value: s.mediaOnDemand,
            onChanged: (value) => _change((c) => c.copyWith(mediaOnDemand: value)),
          ),
          FutureBuilder<int>(
            future: _cacheSize,
            builder: (context, snapshot) {
              final mb = (snapshot.data ?? 0) / (1024 * 1024);
              return ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(l.mediaClearCache),
                subtitle: Text(l.mediaCacheSize(formatNumber(mb))),
                onTap: () async {
                  await ref.read(mediaCacheProvider).clear();
                  if (!mounted) return;
                  setState(() => _cacheSize = ref.read(mediaCacheProvider).sizeInBytes());
                  showMessage(this.context, l.mediaCacheCleared);
                },
              );
            },
          ),

          _header(l.settingsData),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l.dataExportJson),
            subtitle: Text(l.dataExportJsonHint),
            onTap: () => exportJsonBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(l.dataExportCsv),
            subtitle: Text(l.dataExportCsvHint),
            onTap: () => exportCsvTable(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: Text(l.dataImport),
            subtitle: Text(l.dataImportHint),
            onTap: () => importData(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text(l.dataWipe, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: Text(l.dataWipeHint),
            onTap: () => wipeAllData(context, ref),
          ),

          _header(l.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('${l.appTitle} 1.0.0'),
            subtitle: Text(l.aboutPrivacy),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l.aboutImages),
            subtitle: Text(l.aboutImagesHint),
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: Text(l.aboutDisclaimer),
            subtitle: Text(l.aboutDisclaimerHint),
          ),
        ],
      ),
    );
  }
}
