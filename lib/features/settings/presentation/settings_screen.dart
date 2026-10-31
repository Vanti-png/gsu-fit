import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/theme/app_theme.dart';
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

/// Colored rounded-square icon, as in Apple's Settings app.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, this.color, {super.key});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: 17, color: Colors.white),
    );
  }
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(parseInt(controller.text) ?? 0),
            child: Text(l.commonSave, style: const TextStyle(fontWeight: FontWeight.w600)),
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

  /// Inset grouped section: header, rounded card with hairline separators,
  /// optional footer.
  Widget _group({String? title, String? footer, required List<Widget> children}) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 0.5, indent: 56));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(color: palette.textSecondary),
              ),
            ),
          Card(
            child: ListTileTheme.merge(
              minLeadingWidth: 28,
              horizontalTitleGap: 12,
              child: Column(children: rows),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(footer, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  /// Value on the right plus a chevron, like a navigable Settings row.
  Widget _value(String text) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: TextStyle(color: palette.textSecondary)),
        const SizedBox(width: 4),
        Icon(CupertinoIcons.chevron_right, size: 15, color: palette.textTertiary),
      ],
    );
  }

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: child);

  Widget _weekdayChips(Set<int> selected, ValueChanged<int> onTap) {
    final l = context.l10n;
    return _padded(
      Wrap(
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

  Widget _timeTile(String title, int minutes, Future<void> Function(int minutes) onPicked) {
    return ListTile(
      leading: const SizedBox(width: 28),
      title: Text(title),
      trailing: _value(formatMinutesOfDay(minutes)),
      onTap: () async {
        final picked = await _pickTime(minutes);
        if (picked != null) await onPicked(picked);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final theme = Theme.of(context);
    final s = ref.watch(settingsProvider);
    final profile = ref.watch(profileProvider).dataOrNull;
    final targets = ref.watch(nutritionTargetsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            if (profile != null)
              _group(children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(CupertinoIcons.person_crop_circle_fill, size: 44, color: palette.accent),
                  title: Text(
                    profile.name.isEmpty ? l.profileTitle : profile.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text('${l.goal(profile.goal)} · ${l.level(profile.experience)}'),
                  trailing: Icon(CupertinoIcons.chevron_right, size: 15, color: palette.textTertiary),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => EditProfileScreen(profile: profile)),
                  ),
                ),
              ]),

            _group(
              title: l.settingsAppearance,
              children: [
                _padded(
                  Column(
                    children: [
                      AppleSegmented<AppThemeMode>(
                        value: s.themeMode,
                        segments: {for (final mode in AppThemeMode.values) mode: l.themeMode(mode)},
                        onChanged: (mode) => _change((c) => c.copyWith(themeMode: mode)),
                      ),
                      const SizedBox(height: 10),
                      AppleSegmented<WeightUnit>(
                        value: s.weightUnit,
                        segments: {WeightUnit.kg: l.unitKg, WeightUnit.lb: l.unitLb},
                        onChanged: (unit) => _change((c) => c.copyWith(weightUnit: unit)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            _group(
              title: l.settingsWorkout,
              children: [
                ListTile(
                  leading: IconBadge(CupertinoIcons.timer, palette.orange),
                  title: Text(l.settingsDefaultRest),
                  trailing: _value(l.secondsValue('${s.defaultRestSeconds}')),
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
              ],
            ),

            if (kIsWeb)
              _group(
                title: l.settingsReminders,
                children: [
                  ListTile(
                    leading: IconBadge(CupertinoIcons.device_phone_portrait, palette.textSecondary),
                    title: Text(l.webAndroidOnlyTitle),
                    subtitle: Text(l.webRemindersHint),
                  ),
                ],
              )
            else
              _group(
                title: l.settingsReminders,
                children: [
                  SwitchListTile.adaptive(
                    secondary: IconBadge(CupertinoIcons.bell_fill, palette.red),
                    title: Text(l.reminderWorkout),
                    subtitle: Text(l.reminderWorkoutHint),
                    value: s.workoutReminderEnabled,
                    onChanged: (value) =>
                        _changeReminders((c) => c.copyWith(workoutReminderEnabled: value)),
                  ),
                  if (s.workoutReminderEnabled) ...[
                    _weekdayChips(s.workoutReminderDays.toSet(), (day) {
                      final days = s.workoutReminderDays.toSet();
                      if (!days.remove(day)) days.add(day);
                      _changeReminders((c) => c.copyWith(workoutReminderDays: days.toList()..sort()));
                    }),
                    _timeTile(
                      l.reminderTime,
                      s.workoutReminderMinutes,
                      (minutes) =>
                          _changeReminders((c) => c.copyWith(workoutReminderMinutes: minutes)),
                    ),
                  ],
                  SwitchListTile.adaptive(
                    secondary: IconBadge(CupertinoIcons.drop_fill, palette.teal),
                    title: Text(l.reminderWater),
                    subtitle: Text(l.reminderWaterHint(
                      '${s.waterReminderIntervalHours}',
                      '${s.waterReminderStartHour}',
                      '${s.waterReminderEndHour}',
                    )),
                    value: s.waterReminderEnabled,
                    onChanged: (value) =>
                        _changeReminders((c) => c.copyWith(waterReminderEnabled: value)),
                  ),
                  if (s.waterReminderEnabled) ...[
                    _padded(
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final hours in const [1, 2, 3, 4])
                            ChoiceChip(
                              label: Text(l.reminderEveryHours('$hours')),
                              selected: s.waterReminderIntervalHours == hours,
                              onSelected: (_) => _changeReminders(
                                (c) => c.copyWith(waterReminderIntervalHours: hours),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _timeTile(l.reminderStartHour, s.waterReminderStartHour * 60, (minutes) {
                      final hour = minutes ~/ 60;
                      return _changeReminders((c) => c.copyWith(
                            waterReminderStartHour: hour,
                            waterReminderEndHour:
                                c.waterReminderEndHour < hour ? hour : c.waterReminderEndHour,
                          ));
                    }),
                    _timeTile(l.reminderEndHour, s.waterReminderEndHour * 60, (minutes) {
                      final hour = minutes ~/ 60;
                      return _changeReminders((c) => c.copyWith(
                            waterReminderEndHour: hour,
                            waterReminderStartHour:
                                c.waterReminderStartHour > hour ? hour : c.waterReminderStartHour,
                          ));
                    }),
                  ],
                  SwitchListTile.adaptive(
                    secondary: IconBadge(CupertinoIcons.resize_v, palette.purple),
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
                    _timeTile(
                      l.reminderTime,
                      s.measurementReminderMinutes,
                      (minutes) =>
                          _changeReminders((c) => c.copyWith(measurementReminderMinutes: minutes)),
                    ),
                  ],
                ],
              ),

            _group(
              title: l.settingsGoals,
              footer: l.goalAutoHint,
              children: [
                ListTile(
                  leading: IconBadge(CupertinoIcons.drop_fill, palette.teal),
                  title: Text(l.goalWater),
                  trailing: _value(s.waterGoalMl > 0
                      ? '${formatNumber(s.waterGoalMl, decimals: 0)} ml'
                      : l.goalAuto('${formatNumber(targets?.waterMl ?? 0, decimals: 0)} ml')),
                  onTap: () async {
                    final value = await _askNumber(
                      title: l.goalWater,
                      initial: s.waterGoalMl,
                      suffix: 'ml',
                      helper: l.goalAutoHint,
                    );
                    if (value != null) {
                      await _change((c) => c.copyWith(waterGoalMl: value.clamp(0, 10000)));
                    }
                  },
                ),
                ListTile(
                  leading: IconBadge(CupertinoIcons.flame_fill, palette.orange),
                  title: Text(l.goalCalories),
                  trailing: _value(s.calorieGoal > 0
                      ? l.kcalValue(formatNumber(s.calorieGoal, decimals: 0))
                      : l.goalAuto(l.kcalValue(formatNumber(targets?.calories ?? 0, decimals: 0)))),
                  onTap: () async {
                    final value = await _askNumber(
                      title: l.goalCalories,
                      initial: s.calorieGoal,
                      suffix: 'kcal',
                      helper: l.goalAutoHint,
                    );
                    if (value != null) {
                      await _change((c) => c.copyWith(calorieGoal: value.clamp(0, 10000)));
                    }
                  },
                ),
                ListTile(
                  leading: IconBadge(Icons.directions_walk, palette.green),
                  title: Text(l.goalSteps),
                  trailing: _value(formatNumber(s.stepGoal, decimals: 0)),
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
              ],
            ),

            if (!kIsWeb)
              _group(
                title: l.settingsHealth,
                children: [
                  SwitchListTile.adaptive(
                    secondary: IconBadge(CupertinoIcons.heart_fill, palette.pink),
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
                ],
              ),

            _group(
              title: l.settingsMedia,
              footer: l.mediaQualityHint,
              children: [
                _padded(
                  AppleSegmented<MediaQuality>(
                    value: s.mediaQuality,
                    segments: {
                      MediaQuality.low: l.mediaQualityLow,
                      MediaQuality.high: l.mediaQualityHigh,
                    },
                    onChanged: (quality) => _change((c) => c.copyWith(mediaQuality: quality)),
                  ),
                ),
                SwitchListTile.adaptive(
                  secondary: IconBadge(CupertinoIcons.arrow_down_circle_fill, palette.accent),
                  title: Text(l.mediaOnDemand),
                  subtitle: Text(l.mediaOnDemandHint),
                  value: s.mediaOnDemand,
                  onChanged: (value) => _change((c) => c.copyWith(mediaOnDemand: value)),
                ),
                if (!kIsWeb)
                  FutureBuilder<int>(
                    future: _cacheSize,
                    builder: (context, snapshot) {
                      final mb = (snapshot.data ?? 0) / (1024 * 1024);
                      return ListTile(
                        leading: IconBadge(CupertinoIcons.trash_fill, palette.textSecondary),
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
              ],
            ),

            _group(
              title: l.settingsData,
              children: [
                if (kIsWeb)
                  ListTile(
                    leading: IconBadge(CupertinoIcons.info, palette.textSecondary),
                    title: Text(l.webStorageTitle),
                    subtitle: Text(l.webStorageNote),
                  ),
                ListTile(
                  leading: IconBadge(CupertinoIcons.cloud_download_fill, palette.accent),
                  title: Text(l.dataExportJson),
                  subtitle: Text(l.dataExportJsonHint),
                  onTap: () => exportJsonBackup(context, ref),
                ),
                ListTile(
                  leading: IconBadge(CupertinoIcons.table, palette.green),
                  title: Text(l.dataExportCsv),
                  subtitle: Text(l.dataExportCsvHint),
                  onTap: () => exportCsvTable(context, ref),
                ),
                ListTile(
                  leading: IconBadge(CupertinoIcons.tray_arrow_down_fill, palette.purple),
                  title: Text(l.dataImport),
                  subtitle: Text(l.dataImportHint),
                  onTap: () => importData(context, ref),
                ),
                ListTile(
                  leading: IconBadge(CupertinoIcons.delete, palette.red),
                  title: Text(l.dataWipe, style: TextStyle(color: palette.red)),
                  subtitle: Text(l.dataWipeHint),
                  onTap: () => wipeAllData(context, ref),
                ),
              ],
            ),

            _group(
              title: l.settingsAbout,
              children: [
                ListTile(
                  leading: const AppMark(size: 28),
                  title: Text('${l.appTitle} 1.0.0'),
                  subtitle: Text(l.aboutPrivacy),
                ),
                ListTile(
                  leading: IconBadge(CupertinoIcons.photo, palette.accent),
                  title: Text(l.aboutImages),
                  subtitle: Text(l.aboutImagesHint),
                ),
                ListTile(
                  leading: IconBadge(CupertinoIcons.exclamationmark_shield_fill, palette.orange),
                  title: Text(l.aboutDisclaimer),
                  subtitle: Text(l.aboutDisclaimerHint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
