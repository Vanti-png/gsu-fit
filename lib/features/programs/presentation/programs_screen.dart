import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/programs/application/program_providers.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/programs/domain/program_generator.dart';
import 'package:gsu_fit/features/programs/domain/program_stats.dart';
import 'package:gsu_fit/features/programs/presentation/program_detail_screen.dart';
import 'package:gsu_fit/features/programs/presentation/program_labels.dart';
import 'package:gsu_fit/features/settings/presentation/settings_screen.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';

class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final programs = ref.watch(programsProvider);
    final workouts = ref.watch(workoutsProvider).dataOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.programsTitle),
        actions: [SettingsAction(onOpen: () => openSettings(context))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'programs-fab',
        onPressed: () => showNewProgramSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.programNew),
      ),
      body: AsyncValueView<List<Program>>(
        value: programs,
        onRetry: () => ref.invalidate(programsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.event_note,
              title: l.programsEmpty,
              message: l.programsEmptyHint,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final program = list[index];
              final progress = programProgress(program, workouts, DateTime.now());
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProgramDetailScreen(programId: program.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                program.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (program.isActive) Pill(l.programActive),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l.split(program.split)} · ${l.programDaysPerWeek('${program.days.length}')}'
                          ' · ${l.programWeeks('${program.durationWeeks}')}',
                        ),
                        const SizedBox(height: 12),
                        ProgressBar(value: progress.totalFraction),
                        const SizedBox(height: 4),
                        Text(
                          l.programTotalProgress(
                            '${progress.completedTotal}',
                            '${progress.plannedTotal}',
                            '${(progress.totalFraction * 100).round()}',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Generate from the profile, pick a split, or start empty.
Future<void> showNewProgramSheet(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: Text(l.programFromProfile),
            subtitle: Text(l.programFromProfileHint),
            onTap: () => Navigator.of(context).pop('profile'),
          ),
          for (final split in [ProgramSplit.fullBody, ProgramSplit.upperLower, ProgramSplit.pushPullLegs])
            ListTile(
              leading: const Icon(Icons.view_week_outlined),
              title: Text(l.split(split)),
              subtitle: Text(l.programTemplateHint),
              onTap: () => Navigator.of(context).pop(split.name),
            ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(l.programEmpty),
            subtitle: Text(l.programEmptyHint),
            onTap: () => Navigator.of(context).pop('empty'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  final repository = ref.read(programRepositoryProvider);
  Program program;
  if (choice == 'empty') {
    final name = await _askName(context, l.programEmpty);
    if (name == null || !context.mounted) return;
    final programId = newId();
    program = Program(
      id: programId,
      name: name,
      split: ProgramSplit.custom,
      startDate: DateTime.now(),
      days: [ProgramDay(id: newId(), programId: programId, name: l.programDayDefault('1'), position: 0)],
    );
  } else {
    final profile = await ref.read(profileProvider.future);
    if (profile == null || !context.mounted) return;
    final split = choice == 'profile'
        ? null
        : ProgramSplit.values.firstWhere((s) => s.name == choice);
    final days = switch (split) {
      ProgramSplit.upperLower => 4,
      ProgramSplit.pushPullLegs => profile.daysPerWeek >= 6 ? 6 : 3,
      ProgramSplit.fullBody => 3,
      _ => null,
    };
    program = ProgramGenerator(labels: programLabels(l)).generate(profile, split: split, days: days);
    final keep = await _preview(context, ref, program);
    if (keep != true || !context.mounted) return;
  }

  await repository.saveFull(program);
  ref.invalidate(programsProvider);
  if (!context.mounted) return;
  final activate = await confirmDialog(
    context,
    title: l.programActivateTitle,
    message: l.programActivateMessage(program.name),
    confirmLabel: l.programActivate,
  );
  if (activate) {
    await repository.setActive(program.id);
    ref.invalidate(programsProvider);
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ProgramDetailScreen(programId: program.id)),
  );
}

Future<String?> _askName(BuildContext context, String initial) async {
  final l = context.l10n;
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.programName),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: fieldDecoration(l.programName),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.commonCancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(l.commonSave),
        ),
      ],
    ),
  );
  controller.dispose();
  return (name == null || name.isEmpty) ? null : name;
}

/// Lists the generated days so the user can accept or cancel.
Future<bool?> _preview(BuildContext context, WidgetRef ref, Program program) async {
  final l = context.l10n;
  final exercises = await ref.read(exerciseMapProvider.future);
  if (!context.mounted) return null;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(program.name),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(program.description),
            const SizedBox(height: 12),
            for (final day in program.days) ...[
              Text(day.name, style: Theme.of(context).textTheme.titleSmall),
              for (final item in day.exercises)
                Text(
                  '• ${exercises[item.exerciseId]?.name ?? item.exerciseId} — '
                  '${item.sets} × ${item.minReps}–${item.maxReps}',
                ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.commonCancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.programCreate)),
      ],
    ),
  );
}
