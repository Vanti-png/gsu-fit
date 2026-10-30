import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/cardio/domain/calorie_calculator.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId, this.justFinished = false});

  final String workoutId;
  final bool justFinished;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.workoutDeleteTitle,
      message: l.workoutDeleteMessage,
      confirmLabel: l.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(workoutRepositoryProvider).deleteWorkout(workoutId);
    ref.invalidate(workoutsProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final workouts = ref.watch(workoutsProvider);
    final exercises = ref.watch(exerciseMapProvider).dataOrNull ?? const {};
    final unit = ref.watch(settingsProvider.select((s) => s.weightUnit));
    final bodyWeight = ref.watch(profileProvider).dataOrNull?.weightKg ?? 70;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.workoutSummary),
        actions: [
          IconButton(
            tooltip: l.commonDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: AsyncValueView(
        value: workouts,
        onRetry: () => ref.invalidate(workoutsProvider),
        data: (list) {
          final workout = list.where((w) => w.id == workoutId).firstOrNull;
          if (workout == null) {
            return EmptyState(icon: Icons.search_off, title: l.workoutNotFound);
          }
          final calories = CalorieCalculator.strength(duration: workout.duration, weightKg: bodyWeight);
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              if (justFinished)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.emoji_events, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(l.workoutCongrats, style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ),
              SectionCard(
                title: workout.name,
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Fact(label: l.commonDate, value: formatDateTime(workout.startedAt)),
                    _Fact(label: l.statTime, value: l.duration(workout.duration)),
                    _Fact(label: l.statVolume, value: formatWeight(workout.totalVolumeKg, unit, decimals: 0)),
                    _Fact(label: l.statSets, value: '${workout.completedSetCount}'),
                    _Fact(label: l.statCalories, value: l.kcalValue(formatNumber(calories, decimals: 0))),
                  ],
                ),
              ),
              for (final exerciseId in workout.exerciseIds)
                SectionCard(
                  title: exercises[exerciseId]?.name ?? l.exerciseDeleted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, set) in workout.setsFor(exerciseId).indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(width: 32, child: Text('${index + 1}')),
                              Expanded(
                                child: Text(
                                  (exercises[exerciseId]?.isTimed ?? false)
                                      ? l.secondsValue('${set.reps}')
                                      : l.repsValue('${set.reps}'),
                                ),
                              ),
                              Text(set.weightKg > 0 ? formatWeight(set.weightKg, unit) : '—'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (workout.notes.isNotEmpty)
                SectionCard(title: l.workoutNotes, child: Text(workout.notes)),
            ],
          );
        },
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
