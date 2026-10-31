import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/cardio/application/cardio_providers.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';
import 'package:gsu_fit/features/cardio/presentation/cardio_form_sheet.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';
import 'package:gsu_fit/features/workout/presentation/active_workout_screen.dart';
import 'package:gsu_fit/features/workout/presentation/workout_detail_screen.dart';

/// All strength and cardio sessions, newest first.
class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(l.historyAddWorkout),
              subtitle: Text(l.historyAddWorkoutHint),
              onTap: () => Navigator.of(context).pop('workout'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: Text(l.historyAddCardio),
              onTap: () => Navigator.of(context).pop('cardio'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'workout') {
      await startFreeWorkout(context, ref, manual: true);
    } else if (choice == 'cardio') {
      await showCardioForm(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final workouts = ref.watch(workoutsProvider);
    final cardio = ref.watch(cardioSessionsProvider).dataOrNull ?? const [];
    final unit = ref.watch(settingsProvider.select((s) => s.weightUnit));

    return Scaffold(
      appBar: AppBar(title: Text(l.historyTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'history-fab',
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.historyAdd),
      ),
      body: ReadableWidth(child: AsyncValueView<List<Workout>>(
        value: workouts,
        onRetry: () => ref.invalidate(workoutsProvider),
        data: (list) {
          final items = <(DateTime, Widget)>[
            for (final workout in list)
              (
                workout.startedAt,
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                  title: Text(workout.name),
                  subtitle: Text(
                    '${formatDateTime(workout.startedAt)} · ${l.duration(workout.duration)} · '
                    '${formatWeight(workout.totalVolumeKg, unit, decimals: 0)}',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WorkoutDetailScreen(workoutId: workout.id),
                    ),
                  ),
                ),
              ),
            for (final session in cardio)
              (
                session.startedAt,
                _CardioTile(session: session),
              ),
          ]..sort((a, b) => b.$1.compareTo(a.$1));
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: l.historyEmpty,
              message: l.historyEmptyHint,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => items[index].$2,
          );
        },
      )),
    );
  }
}

class _CardioTile extends ConsumerWidget {
  const _CardioTile({required this.session});

  final CardioSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final distance = session.distanceKm;
    return ListTile(
      leading: CircleAvatar(child: Icon(cardioIcon(session.type))),
      title: Text(l.cardioType(session.type)),
      subtitle: Text([
        formatDateTime(session.startedAt),
        l.duration(session.duration),
        if (distance != null && distance > 0) formatDistance(distance),
        l.kcalValue(formatNumber(session.calories, decimals: 0)),
      ].join(' · ')),
      onTap: () => showCardioForm(context, existing: session),
    );
  }
}
