import 'package:flutter/material.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_form_screen.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_list.dart';
import 'package:gsu_fit/features/settings/presentation/settings_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.libraryTitle),
        actions: [SettingsAction(onOpen: () => openSettings(context))],
      ),
      body: ExerciseList(
        onSelected: (exercise) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ExerciseDetailScreen(exerciseId: exercise.id)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'library-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ExerciseFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(l.exerciseAdd),
      ),
    );
  }
}
