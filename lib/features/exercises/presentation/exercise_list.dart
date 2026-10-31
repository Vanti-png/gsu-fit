import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/utils/text.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_media.dart';

/// Searchable, filterable exercise list shared by the library and the
/// exercise picker.
class ExerciseList extends ConsumerStatefulWidget {
  const ExerciseList({super.key, required this.onSelected, this.trailing});

  final ValueChanged<Exercise> onSelected;
  final Widget Function(Exercise exercise)? trailing;

  @override
  ConsumerState<ExerciseList> createState() => _ExerciseListState();
}

class _ExerciseListState extends ConsumerState<ExerciseList> {
  final TextEditingController _search = TextEditingController();
  MuscleGroup? _muscle;
  Equipment? _equipment;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Exercise> _filter(List<Exercise> all) {
    final query = searchKey(_search.text.trim());
    final l = context.l10n;
    return all.where((exercise) {
      if (_muscle != null &&
          !exercise.primaryMuscles.contains(_muscle) &&
          !exercise.secondaryMuscles.contains(_muscle)) {
        return false;
      }
      if (_equipment != null && exercise.equipment != _equipment) return false;
      if (query.isEmpty) return true;
      final haystack = searchKey([
        exercise.name,
        ...exercise.primaryMuscles.map(l.muscle),
        l.equipment(exercise.equipment),
      ].join(' '));
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _pickEquipment() async {
    final l = context.l10n;
    final picked = await showModalBottomSheet<Equipment?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: Text(l.filterAllEquipment),
              onTap: () => Navigator.of(context).pop(null),
            ),
            for (final equipment in Equipment.values)
              ListTile(
                title: Text(l.equipment(equipment)),
                trailing: equipment == _equipment ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(equipment),
              ),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _equipment = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final exercises = ref.watch(exercisesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: searchDecoration(
              context,
              l.librarySearchHint,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.commonClear,
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.tune, size: 18),
                  label: Text(_equipment == null ? l.filterEquipment : l.equipment(_equipment!)),
                  onPressed: _pickEquipment,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(l.filterAll),
                  selected: _muscle == null,
                  onSelected: (_) => setState(() => _muscle = null),
                ),
              ),
              for (final muscle in MuscleGroup.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(l.muscle(muscle)),
                    selected: _muscle == muscle,
                    onSelected: (selected) => setState(() => _muscle = selected ? muscle : null),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<Exercise>>(
            value: exercises,
            onRetry: () => ref.invalidate(exercisesProvider),
            data: (all) {
              final filtered = _filter(all);
              if (filtered.isEmpty) {
                return EmptyState(icon: Icons.search_off, title: l.libraryNoResults);
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 88),
                itemBuilder: (context, index) {
                  final exercise = filtered[index];
                  return ListTile(
                    leading: ExerciseThumbnail(exercise: exercise),
                    title: Text(exercise.name),
                    subtitle: Text(
                      '${exercise.primaryMuscles.map(l.muscle).join(', ')} · '
                      '${l.equipment(exercise.equipment)}',
                    ),
                    trailing: widget.trailing?.call(exercise) ??
                        (exercise.isCustom ? Pill(l.exerciseCustom) : null),
                    onTap: () => widget.onSelected(exercise),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
