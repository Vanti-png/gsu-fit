import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';

/// Creates or edits a custom exercise.
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key, this.existing});

  final Exercise? existing;

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _instructions;
  late final TextEditingController _image;
  late final TextEditingController _video;
  late final TextEditingController _videoLow;
  late ExerciseCategory _category;
  late Equipment _equipment;
  late Set<MuscleGroup> _primary;
  late Set<MuscleGroup> _secondary;
  late bool _timed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _instructions = TextEditingController(text: e?.instructions.join('\n') ?? '');
    _image = TextEditingController(text: e?.imageUrls.join('\n') ?? '');
    _video = TextEditingController(text: e?.videoUrl ?? '');
    _videoLow = TextEditingController(text: e?.videoUrlLow ?? '');
    _category = e?.category ?? ExerciseCategory.strength;
    _equipment = e?.equipment ?? Equipment.dumbbell;
    _primary = {...?e?.primaryMuscles};
    _secondary = {...?e?.secondaryMuscles};
    _timed = e?.isTimed ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    _image.dispose();
    _video.dispose();
    _videoLow.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController controller) => controller.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final l = context.l10n;
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_primary.isEmpty) {
      showMessage(context, l.validationMuscle);
      return;
    }
    setState(() => _saving = true);
    final existing = widget.existing;
    final exercise = Exercise(
      id: existing?.id ?? newId(),
      name: _name.text.trim(),
      category: _category,
      primaryMuscles: _primary.toList(),
      secondaryMuscles: _secondary.difference(_primary).toList(),
      equipment: _equipment,
      instructions: _lines(_instructions),
      imageUrls: _lines(_image),
      isTimed: _timed,
      isCustom: true,
      createdAt: existing?.createdAt,
    ).withVideos(high: _video.text, low: _videoLow.text);
    try {
      await ref.read(exerciseRepositoryProvider).save(exercise);
      ref.invalidate(exercisesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, l.errorSaveFailed);
    }
  }

  Widget _muscleChips(Set<MuscleGroup> selected) {
    final l = context.l10n;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final muscle in MuscleGroup.values)
          FilterChip(
            label: Text(l.muscle(muscle)),
            selected: selected.contains(muscle),
            onSelected: (value) => setState(() {
              if (value) {
                selected.add(muscle);
              } else {
                selected.remove(muscle);
              }
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? l.exerciseAdd : l.exerciseEdit),
      ),
      body: ReadableWidth(child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: fieldDecoration(l.exerciseName),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? l.validationRequired : null,
            ),
            const SizedBox(height: 16),
            Text(l.exerciseCategory, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in ExerciseCategory.values)
                  ChoiceChip(
                    label: Text(l.category(category)),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.exerciseEquipment, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final equipment in Equipment.values)
                  ChoiceChip(
                    label: Text(l.equipment(equipment)),
                    selected: _equipment == equipment,
                    onSelected: (_) => setState(() => _equipment = equipment),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.exercisePrimary, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            _muscleChips(_primary),
            const SizedBox(height: 16),
            Text(l.exerciseSecondary, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            _muscleChips(_secondary),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.exerciseTimed),
              subtitle: Text(l.exerciseTimedHint),
              value: _timed,
              onChanged: (value) => setState(() => _timed = value),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructions,
              minLines: 3,
              maxLines: 10,
              decoration: fieldDecoration(l.exerciseInstructions, helper: l.exerciseInstructionsHint),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _image,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.url,
              decoration: fieldDecoration(l.exerciseImageUrls, helper: l.exerciseImageUrlsHint),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _video,
              keyboardType: TextInputType.url,
              decoration: fieldDecoration(l.videoUrlHigh, hint: 'https://…'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _videoLow,
              keyboardType: TextInputType.url,
              decoration: fieldDecoration(l.videoUrlLow, hint: 'https://…'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.commonSave),
            ),
          ],
        ),
      )),
    );
  }
}
