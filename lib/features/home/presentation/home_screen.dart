import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/body/presentation/measurement_form_sheet.dart';
import 'package:gsu_fit/features/cardio/presentation/cardio_form_sheet.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/home/presentation/home_shell.dart';
import 'package:gsu_fit/features/nutrition/application/nutrition_actions.dart';
import 'package:gsu_fit/features/nutrition/presentation/food_form_sheet.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/programs/application/program_providers.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/program_stats.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/settings/presentation/settings_screen.dart';
import 'package:gsu_fit/features/steps/presentation/steps_card.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/features/workout/domain/workout_stats.dart';
import 'package:gsu_fit/features/workout/presentation/active_workout_screen.dart';
import 'package:gsu_fit/features/workout/presentation/workout_history_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final name = ref.watch(profileProvider).dataOrNull?.name ?? '';
    return Scaffold(
      appBar: AppBar(
        // Large left-aligned title, like the first screen of an Apple app.
        centerTitle: false,
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDateWithWeekday(DateTime.now()),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              name.isEmpty ? l.homeGreetingNoName : l.homeGreeting(name),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.historyTitle,
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WorkoutHistoryScreen()),
            ),
          ),
          SettingsAction(onOpen: () => openSettings(context)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workoutsProvider);
          ref.invalidate(programsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: const [
            _TodayWorkoutCard(),
            _WeeklySummaryCard(),
            _QuickLogCard(),
            // Health Connect exists only on Android.
            if (!kIsWeb) StepsCard(),
          ],
        ),
      ),
    );
  }
}

/// Rough session length: ~40 s per set plus the programmed rest.
Duration estimateDayDuration(ProgramDay day) {
  var seconds = 0;
  for (final item in day.exercises) {
    seconds += item.sets * (40 + item.restSeconds);
  }
  return Duration(seconds: seconds);
}

class _TodayWorkoutCard extends ConsumerWidget {
  const _TodayWorkoutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final programAsync = ref.watch(activeProgramProvider);
    final workouts = ref.watch(workoutsProvider).dataOrNull ?? const [];
    final exercises = ref.watch(exerciseMapProvider).dataOrNull ?? const {};

    return SectionCard(
      title: l.homeTodayWorkout,
      child: programAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => Text(l.errorLoadFailed),
        data: (program) {
          if (program == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.homeNoActiveProgram),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => ref.read(homeTabProvider.notifier).select(1),
                  icon: const Icon(Icons.event_note),
                  label: Text(l.homeChooseProgram),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => startFreeWorkout(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(l.workoutStartFree),
                ),
              ],
            );
          }
          final day = nextProgramDay(program, workouts);
          if (day == null) return Text(l.programNoDays);
          final now = DateTime.now();
          final progress = programProgress(program, workouts, now);
          final names = [
            for (final item in day.exercises) exercises[item.exerciseId]?.name ?? '…',
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(program.name, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: Text(day.name, style: theme.textTheme.headlineSmall)),
                  if (trainedToday(program, workouts, now)) Pill(l.homeDoneToday),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${l.exerciseCount('${day.exercises.length}')} · '
                '${l.homeEstimated(l.duration(estimateDayDuration(day)))}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in names.take(6)) Chip(label: Text(name)),
                  if (names.length > 6) Chip(label: Text('+${names.length - 6}')),
                ],
              ),
              const SizedBox(height: 12),
              ProgressBar(value: progress.weekFraction),
              const SizedBox(height: 4),
              Text(
                l.programWeekProgress('${progress.completedThisWeek}', '${progress.plannedPerWeek}'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => startProgramWorkout(context, ref, program, day),
                icon: const Icon(Icons.play_arrow),
                label: Text(l.workoutStart),
              ),
              TextButton(
                onPressed: () => startFreeWorkout(context, ref),
                child: Text(l.workoutStartFree),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WeeklySummaryCard extends ConsumerWidget {
  const _WeeklySummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final summary = ref.watch(weeklySummaryProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.weightUnit));
    return SectionCard(
      title: l.homeWeeklySummary,
      child: AsyncValueView<WeeklySummary>(
        value: summary,
        onRetry: () => ref.invalidate(weeklySummaryProvider),
        data: (s) {
          final change = s.volumeChange;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WeekDots(active: s.activeWeekdays),
              const SizedBox(height: 12),
              Text(l.homeWeekTarget('${s.activeWeekdays.length}', '${s.targetDays}')),
              const SizedBox(height: 6),
              ProgressBar(value: s.targetFraction),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatTile(
                    icon: Icons.fitness_center,
                    label: l.statWorkouts,
                    value: '${s.workoutCount}',
                  ),
                  _StatTile(
                    icon: Icons.directions_run,
                    label: l.statCardio,
                    value: '${s.cardioCount}',
                  ),
                  _StatTile(
                    icon: Icons.timer_outlined,
                    label: l.statTime,
                    value: l.duration(s.trainingTime),
                  ),
                  _StatTile(
                    icon: Icons.stacked_bar_chart,
                    label: l.statVolume,
                    value: formatWeight(s.volumeKg, unit, decimals: 0),
                  ),
                  _StatTile(
                    icon: Icons.local_fire_department_outlined,
                    label: l.statCalories,
                    value: l.kcalValue(formatNumber(s.caloriesBurned, decimals: 0)),
                  ),
                  if (s.cardioDistanceKm > 0)
                    _StatTile(
                      icon: Icons.route,
                      label: l.statDistance,
                      value: formatDistance(s.cardioDistanceKm),
                    ),
                ],
              ),
              if (change != null) ...[
                const SizedBox(height: 12),
                Text(
                  l.homeVolumeChange(
                    '${change >= 0 ? '+' : ''}${formatNumber(change * 100, decimals: 0)}%',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.active});

  final Set<int> active;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now().weekday;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var day = 1; day <= 7; day++)
          Semantics(
            label: '${l.weekdayLong(day)}: ${active.contains(day) ? l.commonDone : l.commonNotDone}',
            child: Column(
              children: [
                Text(
                  l.weekdayShort(day),
                  style: TextStyle(
                    fontWeight: day == today ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      active.contains(day) ? scheme.primary : scheme.surfaceContainerHighest,
                  child: active.contains(day)
                      ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.titleMedium),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLogCard extends ConsumerWidget {
  const _QuickLogCard();

  Future<void> _addWater(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final actions = ref.read(nutritionActionsProvider);
    final entry = await actions.addWater(dayKey(DateTime.now()), 250);
    if (!context.mounted) return;
    showMessage(
      context,
      l.waterAdded('250'),
      action: SnackBarAction(label: l.commonUndo, onPressed: () => actions.deleteWater(entry)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final buttons = <(IconData, String, VoidCallback)>[
      (Icons.water_drop_outlined, l.quickWater, () => _addWater(context, ref)),
      (Icons.directions_run, l.quickCardio, () => showCardioForm(context)),
      (Icons.monitor_weight_outlined, l.quickMeasurement, () => showMeasurementForm(context)),
      (
        Icons.restaurant_outlined,
        l.quickFood,
        () => showFoodForm(context, day: dayKey(DateTime.now())),
      ),
    ];
    return SectionCard(
      title: l.homeQuickLog,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = max(120.0, (constraints.maxWidth - 8) / 2);
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, label, onPressed) in buttons)
                SizedBox(
                  width: width,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: onPressed,
                    icon: Icon(icon),
                    label: Text(label),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
