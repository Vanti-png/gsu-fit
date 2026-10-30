import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/programs/application/program_providers.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/program_stats.dart';
import 'package:gsu_fit/features/programs/presentation/program_day_editor_screen.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/features/workout/presentation/active_workout_screen.dart';

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final String programId;

  Future<void> _rename(BuildContext context, WidgetRef ref, Program program) async {
    final l = context.l10n;
    final name = TextEditingController(text: program.name);
    final description = TextEditingController(text: program.description);
    final weeks = TextEditingController(text: '${program.durationWeeks}');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.programEdit),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: fieldDecoration(l.programName)),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                minLines: 2,
                maxLines: 5,
                decoration: fieldDecoration(l.programDescriptionLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weeks,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(l.programDuration, suffix: l.unitWeeksShort),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.commonCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.commonSave)),
        ],
      ),
    );
    final values = (name.text.trim(), description.text.trim(), int.tryParse(weeks.text.trim()));
    name.dispose();
    description.dispose();
    weeks.dispose();
    if (save != true) return;
    await ref.read(programRepositoryProvider).saveProgram(program.copyWith(
          name: values.$1.isEmpty ? program.name : values.$1,
          description: values.$2,
          durationWeeks: (values.$3 ?? program.durationWeeks).clamp(1, 52),
        ));
    ref.invalidate(programsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Program program) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.programDeleteTitle,
      message: l.programDeleteMessage(program.name),
      confirmLabel: l.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(programRepositoryProvider).deleteProgram(program.id);
    ref.invalidate(programsProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _addDay(WidgetRef ref, Program program, AppLocalizations l) async {
    final day = ProgramDay(
      id: newId(),
      programId: program.id,
      name: l.programDayDefault('${program.days.length + 1}'),
      position: program.days.length,
    );
    await ref.read(programRepositoryProvider).saveDay(day);
    ref.invalidate(programsProvider);
  }

  Future<void> _moveDay(WidgetRef ref, List<ProgramDay> days, int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= days.length) return;
    final repository = ref.read(programRepositoryProvider);
    await repository.saveDay(days[index].copyWith(position: target));
    await repository.saveDay(days[target].copyWith(position: index));
    ref.invalidate(programsProvider);
  }

  Future<void> _deleteDay(BuildContext context, WidgetRef ref, ProgramDay day) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.programDayDeleteTitle,
      message: l.programDayDeleteMessage(day.name),
      confirmLabel: l.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(programRepositoryProvider).deleteDay(day.id);
    ref.invalidate(programsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final programs = ref.watch(programsProvider);
    final exercises = ref.watch(exerciseMapProvider).dataOrNull ?? const {};
    final workouts = ref.watch(workoutsProvider).dataOrNull ?? const [];

    // Material gives the loading/error states a background; the loaded
    // state brings its own Scaffold.
    return Material(
      child: AsyncValueView<List<Program>>(
      value: programs,
      onRetry: () => ref.invalidate(programsProvider),
      data: (list) {
        final program = list.where((p) => p.id == programId).firstOrNull;
        if (program == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(icon: Icons.search_off, title: l.programNotFound),
          );
        }
        final days = [...program.days]..sort((a, b) => a.position.compareTo(b.position));
        final progress = programProgress(program, workouts, DateTime.now());
        final next = nextProgramDay(program, workouts);
        return Scaffold(
          appBar: AppBar(
            title: Text(program.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _rename(context, ref, program);
                    case 'delete':
                      _delete(context, ref, program);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(l.programEdit)),
                  PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'program-day-fab',
            onPressed: () => _addDay(ref, program, l),
            icon: const Icon(Icons.add),
            label: Text(l.programAddDay),
          ),
          body: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l.split(program.split), style: theme.textTheme.titleMedium)),
                        if (program.isActive) Pill(l.programActive),
                      ],
                    ),
                    if (program.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(program.description),
                    ],
                    const SizedBox(height: 16),
                    Text(l.programThisWeek, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    ProgressBar(value: progress.weekFraction),
                    const SizedBox(height: 4),
                    Text(l.programWeekProgress(
                      '${progress.completedThisWeek}',
                      '${progress.plannedPerWeek}',
                    )),
                    const SizedBox(height: 12),
                    Text(l.programOverall, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    ProgressBar(value: progress.totalFraction),
                    const SizedBox(height: 4),
                    Text(l.programTotalProgress(
                      '${progress.completedTotal}',
                      '${progress.plannedTotal}',
                      '${(progress.totalFraction * 100).round()}',
                    )),
                    if (!program.isActive) ...[
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () async {
                          await ref.read(programRepositoryProvider).setActive(program.id);
                          ref.invalidate(programsProvider);
                        },
                        child: Text(l.programActivate),
                      ),
                    ],
                  ],
                ),
              ),
              if (days.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.programNoDays, textAlign: TextAlign.center),
                ),
              for (var i = 0; i < days.length; i++)
                SectionCard(
                  title: days[i].name,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (next?.id == days[i].id) Pill(l.programNext),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'up':
                              _moveDay(ref, days, i, -1);
                            case 'down':
                              _moveDay(ref, days, i, 1);
                            case 'delete':
                              _deleteDay(context, ref, days[i]);
                          }
                        },
                        itemBuilder: (context) => [
                          if (i > 0) PopupMenuItem(value: 'up', child: Text(l.commonMoveUp)),
                          if (i < days.length - 1)
                            PopupMenuItem(value: 'down', child: Text(l.commonMoveDown)),
                          PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
                        ],
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (days[i].exercises.isEmpty) Text(l.programDayEmpty),
                      for (final item in days[i].exercises)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(exercises[item.exerciseId]?.name ?? l.exerciseDeleted)),
                              Text(
                                l.programSetsReps('${item.sets}', '${item.minReps}–${item.maxReps}'),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ProgramDayEditorScreen(
                                    programId: program.id,
                                    dayId: days[i].id,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.edit),
                              label: Text(l.commonEdit),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: days[i].exercises.isEmpty
                                  ? null
                                  : () => startProgramWorkout(context, ref, program, days[i]),
                              icon: const Icon(Icons.play_arrow),
                              label: Text(l.workoutStart),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
      ),
    );
  }
}
