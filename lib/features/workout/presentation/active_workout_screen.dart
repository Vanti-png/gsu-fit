import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_picker_screen.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_media.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/progression.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/workout/application/active_workout_controller.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';
import 'package:gsu_fit/features/workout/domain/workout_stats.dart';
import 'package:gsu_fit/features/workout/presentation/workout_detail_screen.dart';
import 'package:gsu_fit/features/workout/presentation/workout_widgets.dart';

Future<void> _push(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ActiveWorkoutScreen()),
    );

/// Returns true when a new session may start. An open session is either
/// resumed (returns false) or discarded after asking.
Future<bool> _resolveOpenWorkout(BuildContext context, WidgetRef ref) async {
  final open =
      ref.read(activeWorkoutProvider)?.workout ?? await ref.read(unfinishedWorkoutProvider.future);
  if (open == null) return true;
  if (!context.mounted) return false;
  final l = context.l10n;
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.workoutOpenTitle),
      content: Text(l.workoutOpenMessage(open.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.workoutResume),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.workoutDiscardAndStart),
        ),
      ],
    ),
  );
  if (discard == null || !context.mounted) return false;
  final notifier = ref.read(activeWorkoutProvider.notifier);
  if (ref.read(activeWorkoutProvider) == null) await notifier.resume(open);
  if (!discard) {
    if (context.mounted) await _push(context);
    return false;
  }
  await notifier.discard();
  return true;
}

Future<void> startProgramWorkout(
  BuildContext context,
  WidgetRef ref,
  Program program,
  ProgramDay day,
) async {
  if (!await _resolveOpenWorkout(context, ref)) return;
  await ref
      .read(activeWorkoutProvider.notifier)
      .startFromProgramDay(program: program, day: day, name: day.name);
  if (context.mounted) await _push(context);
}

/// Empty session; with [manual] it logs a workout done earlier.
Future<void> startFreeWorkout(BuildContext context, WidgetRef ref, {bool manual = false}) async {
  final l = context.l10n;
  if (!await _resolveOpenWorkout(context, ref)) return;
  await ref
      .read(activeWorkoutProvider.notifier)
      .startEmpty(name: manual ? l.workoutManualName : l.workoutFreeName, manual: manual);
  if (context.mounted) await _push(context);
}

Future<void> openActiveWorkout(BuildContext context, WidgetRef ref, {Workout? resume}) async {
  if (ref.read(activeWorkoutProvider) == null && resume != null) {
    await ref.read(activeWorkoutProvider.notifier).resume(resume);
  }
  if (context.mounted) await _push(context);
}

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  late final TextEditingController _notes;
  late final TextEditingController _manualMinutes;
  late DateTime _manualStart;

  @override
  void initState() {
    super.initState();
    final session = ref.read(activeWorkoutProvider);
    _notes = TextEditingController(text: session?.workout.notes ?? '');
    _manualMinutes = TextEditingController(text: '60');
    _manualStart = session?.workout.startedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _notes.dispose();
    _manualMinutes.dispose();
    super.dispose();
  }

  ActiveWorkoutController get _controller => ref.read(activeWorkoutProvider.notifier);

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise != null) await _controller.addExercise(exercise);
  }

  Future<void> _pickManualStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _manualStart,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_manualStart),
    );
    if (!mounted) return;
    setState(() {
      _manualStart = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _manualStart.hour,
        time?.minute ?? _manualStart.minute,
      );
    });
  }

  Future<void> _discard() async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.workoutDiscardTitle,
      message: l.workoutDiscardMessage,
      confirmLabel: l.workoutDiscard,
      destructive: true,
    );
    if (!ok) return;
    await _controller.discard();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish(ActiveWorkoutState session) async {
    final l = context.l10n;
    final done = session.workout.completedSetCount;
    if (done == 0) {
      final discard = await confirmDialog(
        context,
        title: l.workoutNoSetsTitle,
        message: l.workoutNoSetsMessage,
        confirmLabel: l.workoutDiscard,
        destructive: true,
      );
      if (!discard) return;
      await _controller.discard();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final ok = await confirmDialog(
      context,
      title: l.workoutFinishTitle,
      message: l.workoutFinishMessage('$done', '${session.workout.sets.length}'),
      confirmLabel: l.workoutFinish,
    );
    if (!ok) return;
    final finished = await _controller.finish(
      notes: _notes.text.trim(),
      startedAt: session.isManual ? _manualStart : null,
      duration: session.isManual
          ? Duration(minutes: (parseInt(_manualMinutes.text) ?? 60).clamp(1, 600))
          : null,
    );
    if (!mounted || finished == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutDetailScreen(workoutId: finished.id, justFinished: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(activeWorkoutProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final unit = ref.watch(settingsProvider.select((s) => s.weightUnit));
    final exercises = ref.watch(exerciseMapProvider).dataOrNull ?? const {};
    final history = ref.watch(workoutsProvider).dataOrNull ?? const [];
    final workout = session.workout;
    final restEndsAt = session.restEndsAt;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (!session.isManual)
              ElapsedClock(since: workout.startedAt, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => _finish(session), child: Text(l.workoutFinish)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'discard') _discard();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'discard', child: Text(l.workoutDiscard)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          if (session.isManual)
            SectionCard(
              title: l.workoutManualTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(formatDateTime(_manualStart)),
                    subtitle: Text(l.workoutManualDate),
                    trailing: const Icon(Icons.edit),
                    onTap: _pickManualStart,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _manualMinutes,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecoration(l.workoutDurationMinutes, suffix: l.unitMinutesShort),
                  ),
                ],
              ),
            ),
          if (workout.sets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.workoutEmpty, textAlign: TextAlign.center),
            ),
          for (final exerciseId in workout.exerciseIds)
            _ExerciseCard(
              key: ValueKey(exerciseId),
              exercise: exercises[exerciseId],
              exerciseId: exerciseId,
              sets: workout.setsFor(exerciseId),
              suggestion: session.suggestions[exerciseId],
              target: session.targets[exerciseId],
              previous: lastSessionSets(history, exerciseId, excludeWorkoutId: workout.id),
              unit: unit,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: Text(l.workoutAddExercise),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: fieldDecoration(l.workoutNotes, hint: l.workoutNotesHint),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FilledButton.icon(
              onPressed: () => _finish(session),
              icon: const Icon(Icons.flag),
              label: Text(l.workoutFinish),
            ),
          ),
        ],
      ),
      bottomNavigationBar: restEndsAt == null
          ? null
          : RestTimerBar(
              endsAt: restEndsAt,
              totalSeconds: session.restTotalSeconds,
              onAdjust: _controller.adjustRest,
              onSkip: _controller.skipRest,
              onFinished: () {
                _controller.skipRest();
                showMessage(context, l.restOverBody);
              },
            ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.exerciseId,
    required this.sets,
    required this.suggestion,
    required this.target,
    required this.previous,
    required this.unit,
  });

  final Exercise? exercise;
  final String exerciseId;
  final List<WorkoutSet> sets;
  final ProgressionSuggestion? suggestion;
  final ProgramExercise? target;
  final List<WorkoutSet> previous;
  final WeightUnit unit;

  String _setText(AppLocalizations l, double weightKg, int reps, bool timed) {
    final amount = timed ? l.secondsValue('$reps') : l.repsValue('$reps');
    return weightKg > 0 ? '${formatWeight(weightKg, unit)} × $amount' : amount;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final controller = ref.read(activeWorkoutProvider.notifier);
    final timed = exercise?.isTimed ?? false;
    final hint = suggestion;
    final rx = target;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExerciseThumbnail(exercise: exercise, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise?.name ?? l.exerciseDeleted, style: theme.textTheme.titleMedium),
                    if (rx != null)
                      Text(
                        l.programPrescription(
                          '${rx.sets}',
                          '${rx.minReps}–${rx.maxReps}',
                          '${rx.restSeconds}',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (exercise != null)
                IconButton(
                  tooltip: l.exerciseDetails,
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExerciseDetailScreen(exerciseId: exerciseId),
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value != 'remove') return;
                  final ok = await confirmDialog(
                    context,
                    title: l.workoutRemoveExerciseTitle,
                    message: l.workoutRemoveExerciseMessage,
                    confirmLabel: l.commonRemove,
                    destructive: true,
                  );
                  if (ok) await controller.removeExercise(exerciseId);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'remove', child: Text(l.workoutRemoveExercise)),
                ],
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint.weightKg <= 0 && hint.reason == ProgressionReason.firstSession
                          ? '${l.suggestionLabel}: ${l.progressionReason(hint.reason)}'
                          : '${l.suggestionLabel}: ${_setText(l, hint.weightKg, hint.reps, timed)}'
                              ' — ${l.progressionReason(hint.reason)}',
                      style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (previous.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${l.workoutPrevious}: '
              '${previous.map((s) => _setText(l, s.weightKg, s.reps, timed)).join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          for (var i = 0; i < sets.length; i++)
            Dismissible(
              key: ValueKey('dismiss-${sets[i].id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: theme.colorScheme.errorContainer,
                child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
              ),
              onDismissed: (_) => controller.removeSet(sets[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: SetRow(
                  key: ValueKey(sets[i].id),
                  set: sets[i],
                  number: i + 1,
                  unit: unit,
                  timed: timed,
                  onChanged: controller.updateSet,
                  onToggle: () => controller.toggleComplete(sets[i]),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => controller.addSet(exerciseId),
              icon: const Icon(Icons.add),
              label: Text(l.workoutAddSet),
            ),
          ),
        ],
      ),
    );
  }
}
