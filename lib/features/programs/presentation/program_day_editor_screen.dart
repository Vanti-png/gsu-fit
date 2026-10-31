import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_media.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_picker_screen.dart';
import 'package:gsu_fit/features/programs/application/program_providers.dart';
import 'package:gsu_fit/features/programs/domain/program.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';

/// Edit one program day: exercises, their order and set/rep prescription.
class ProgramDayEditorScreen extends ConsumerWidget {
  const ProgramDayEditorScreen({super.key, required this.programId, required this.dayId});

  final String programId;
  final String dayId;

  ProgramRepository _repository(WidgetRef ref) => ref.read(programRepositoryProvider);

  Future<void> _rename(BuildContext context, WidgetRef ref, ProgramDay day) async {
    final l = context.l10n;
    final controller = TextEditingController(text: day.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.programDayRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: fieldDecoration(l.programDayName),
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
    if (name == null || name.isEmpty) return;
    await _repository(ref).saveDay(day.copyWith(name: name));
    ref.invalidate(programsProvider);
  }

  Future<void> _add(BuildContext context, WidgetRef ref, ProgramDay day) async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise == null) return;
    final settings = ref.read(settingsProvider);
    await _repository(ref).saveProgramExercise(ProgramExercise(
      id: newId(),
      dayId: day.id,
      exerciseId: exercise.id,
      position: day.exercises.length,
      sets: 3,
      minReps: exercise.isTimed ? 30 : 8,
      maxReps: exercise.isTimed ? 60 : 12,
      restSeconds: settings.defaultRestSeconds,
      incrementKg: exercise.usesBodyweight ? 0 : 2.5,
    ));
    ref.invalidate(programsProvider);
  }

  Future<void> _swap(BuildContext context, WidgetRef ref, ProgramExercise item) async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise == null) return;
    await _repository(ref).saveProgramExercise(item.copyWith(exerciseId: exercise.id));
    ref.invalidate(programsProvider);
  }

  Future<void> _move(WidgetRef ref, List<ProgramExercise> items, int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= items.length) return;
    final reordered = [...items];
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);
    await _repository(ref).saveProgramExercises([
      for (var i = 0; i < reordered.length; i++) reordered[i].copyWith(position: i),
    ]);
    ref.invalidate(programsProvider);
  }

  Future<void> _remove(WidgetRef ref, ProgramExercise item) async {
    await _repository(ref).deleteProgramExercise(item.id);
    ref.invalidate(programsProvider);
  }

  Future<void> _editPrescription(
    BuildContext context,
    WidgetRef ref,
    ProgramExercise item,
    Exercise? exercise,
  ) async {
    final updated = await showDialog<ProgramExercise>(
      context: context,
      builder: (_) => _PrescriptionDialog(
        item: item,
        exerciseName: exercise?.name ?? '',
        timed: exercise?.isTimed ?? false,
        unit: ref.read(settingsProvider).weightUnit,
      ),
    );
    if (updated == null) return;
    await _repository(ref).saveProgramExercise(updated);
    ref.invalidate(programsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final programs = ref.watch(programsProvider).dataOrNull;
    final exercises = ref.watch(exerciseMapProvider).dataOrNull ?? const {};
    final day = programs
        ?.where((p) => p.id == programId)
        .firstOrNull
        ?.days
        .where((d) => d.id == dayId)
        .firstOrNull;

    if (day == null) {
      return Scaffold(
        appBar: AppBar(),
        body: programs == null
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(icon: Icons.search_off, title: l.programNotFound),
      );
    }
    final items = [...day.exercises]..sort((a, b) => a.position.compareTo(b.position));

    return Scaffold(
      appBar: AppBar(
        title: Text(day.name),
        actions: [
          IconButton(
            tooltip: l.programDayRename,
            icon: const Icon(Icons.drive_file_rename_outline),
            onPressed: () => _rename(context, ref, day),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'day-editor-fab',
        onPressed: () => _add(context, ref, day),
        icon: const Icon(Icons.add),
        label: Text(l.workoutAddExercise),
      ),
      body: ReadableWidth(child: items.isEmpty
          ? EmptyState(icon: Icons.playlist_add, title: l.programDayEmpty, message: l.programDayEmptyHint)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final exercise = exercises[item.exerciseId];
                final reps = exercise?.isTimed ?? false
                    ? l.secondsValue('${item.minReps}–${item.maxReps}')
                    : '${item.minReps}–${item.maxReps}';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: ExerciseThumbnail(exercise: exercise, size: 48),
                    title: Text(exercise?.name ?? l.exerciseDeleted),
                    subtitle: Text(l.programPrescription('${item.sets}', reps, '${item.restSeconds}')),
                    onTap: () => _editPrescription(context, ref, item, exercise),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'up':
                            _move(ref, items, index, -1);
                          case 'down':
                            _move(ref, items, index, 1);
                          case 'swap':
                            _swap(context, ref, item);
                          case 'remove':
                            _remove(ref, item);
                        }
                      },
                      itemBuilder: (context) => [
                        if (index > 0) PopupMenuItem(value: 'up', child: Text(l.commonMoveUp)),
                        if (index < items.length - 1)
                          PopupMenuItem(value: 'down', child: Text(l.commonMoveDown)),
                        PopupMenuItem(value: 'swap', child: Text(l.programSwapExercise)),
                        PopupMenuItem(value: 'remove', child: Text(l.commonRemove)),
                      ],
                    ),
                  ),
                );
              },
            )),
    );
  }
}

class _PrescriptionDialog extends StatefulWidget {
  const _PrescriptionDialog({
    required this.item,
    required this.exerciseName,
    required this.timed,
    required this.unit,
  });

  final ProgramExercise item;
  final String exerciseName;
  final bool timed;
  final WeightUnit unit;

  @override
  State<_PrescriptionDialog> createState() => _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<_PrescriptionDialog> {
  late int _sets = widget.item.sets;
  late int _minReps = widget.item.minReps;
  late int _maxReps = widget.item.maxReps;
  late int _rest = widget.item.restSeconds;
  late final TextEditingController _startWeight = TextEditingController(
    text: widget.item.startWeightKg == 0
        ? ''
        : formatInputNumber(widget.unit.fromKg(widget.item.startWeightKg)),
  );
  late final TextEditingController _increment = TextEditingController(
    text: formatInputNumber(widget.unit.fromKg(widget.item.incrementKg)),
  );

  @override
  void dispose() {
    _startWeight.dispose();
    _increment.dispose();
    super.dispose();
  }

  Widget _stepper(String label, int value, int step, int min, int max, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: '-$step',
          onPressed: value - step < min ? null : () => onChanged(value - step),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '+$step',
          onPressed: value + step > max ? null : () => onChanged(value + step),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repStep = widget.timed ? 5 : 1;
    final repLabel = widget.timed ? l.unitSecondsShort : l.workoutReps;
    return AlertDialog(
      title: Text(widget.exerciseName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepper(l.programSets, _sets, 1, 1, 10, (v) => setState(() => _sets = v)),
            _stepper('${l.programMinReps} ($repLabel)', _minReps, repStep, 1, 300, (v) {
              setState(() {
                _minReps = v;
                if (_maxReps < v) _maxReps = v;
              });
            }),
            _stepper('${l.programMaxReps} ($repLabel)', _maxReps, repStep, 1, 300, (v) {
              setState(() {
                _maxReps = v;
                if (_minReps > v) _minReps = v;
              });
            }),
            _stepper(l.programRestSeconds, _rest, 15, 0, 600, (v) => setState(() => _rest = v)),
            const SizedBox(height: 12),
            TextField(
              controller: _startWeight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDecoration(
                l.programStartWeight,
                suffix: widget.unit.symbol,
                helper: l.programStartWeightHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _increment,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDecoration(
                l.programIncrement,
                suffix: widget.unit.symbol,
                helper: l.programIncrementHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.commonCancel)),
        FilledButton(
          onPressed: () {
            final start = parseDecimal(_startWeight.text);
            final increment = parseDecimal(_increment.text);
            Navigator.of(context).pop(widget.item.copyWith(
              sets: _sets,
              minReps: _minReps,
              maxReps: _maxReps,
              restSeconds: _rest,
              startWeightKg: start == null ? 0 : cleanDouble(widget.unit.toKg(start)),
              incrementKg: increment == null ? widget.item.incrementKg : cleanDouble(widget.unit.toKg(increment)),
            ));
          },
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
