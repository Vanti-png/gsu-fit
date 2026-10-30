import 'package:flutter/material.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_list.dart';

/// Returns the chosen [Exercise] via Navigator.pop.
class ExercisePickerScreen extends StatelessWidget {
  const ExercisePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.exercisePick)),
      body: ExerciseList(
        onSelected: (exercise) => Navigator.of(context).pop<Exercise>(exercise),
        trailing: (_) => const Icon(Icons.add_circle_outline),
      ),
    );
  }
}
