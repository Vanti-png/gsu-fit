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
import 'package:gsu_fit/features/exercises/presentation/exercise_form_screen.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_media.dart';
import 'package:gsu_fit/features/exercises/presentation/video_player_screen.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/features/workout/domain/workout_stats.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  Future<void> _editVideo(BuildContext context, WidgetRef ref, Exercise exercise) async {
    final l = context.l10n;
    final high = TextEditingController(text: exercise.videoUrl ?? '');
    final low = TextEditingController(text: exercise.videoUrlLow ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.videoEditTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.videoEditHint),
              const SizedBox(height: 12),
              TextField(
                controller: high,
                keyboardType: TextInputType.url,
                decoration: fieldDecoration(l.videoUrlHigh, hint: 'https://…'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: low,
                keyboardType: TextInputType.url,
                decoration: fieldDecoration(l.videoUrlLow, hint: 'https://…'),
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
    final highUrl = high.text;
    final lowUrl = low.text;
    high.dispose();
    low.dispose();
    if (save != true) return;
    await ref.read(exerciseRepositoryProvider).save(exercise.withVideos(high: highUrl, low: lowUrl));
    ref.invalidate(exercisesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Exercise exercise) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.exerciseDeleteTitle,
      message: l.exerciseDeleteMessage(exercise.name),
      confirmLabel: l.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(exerciseRepositoryProvider).delete(exercise.id);
    ref.invalidate(exercisesProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final exercise = ref.watch(exerciseMapProvider).dataOrNull?[exerciseId];
    final settings = ref.watch(settingsProvider);
    final workouts = ref.watch(workoutsProvider).dataOrNull ?? const [];

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final stats = exerciseSessionStats(workouts, exercise.id);
    final unit = settings.weightUnit;
    final video = exercise.videoFor(lowQuality: settings.mediaQuality == MediaQuality.low);

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'video':
                  _editVideo(context, ref, exercise);
                case 'edit':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ExerciseFormScreen(existing: exercise)),
                  );
                case 'delete':
                  _delete(context, ref, exercise);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'video', child: Text(l.videoEditTitle)),
              if (exercise.isCustom) PopupMenuItem(value: 'edit', child: Text(l.commonEdit)),
              if (exercise.isCustom) PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ExerciseMediaView(urls: exercise.imageUrls),
          if (video != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VideoPlayerScreen(source: video, title: exercise.name),
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(l.videoWatch),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(avatar: const Icon(Icons.category_outlined, size: 18), label: Text(l.category(exercise.category))),
                Chip(avatar: const Icon(Icons.handyman_outlined, size: 18), label: Text(l.equipment(exercise.equipment))),
                if (exercise.isTimed)
                  Chip(avatar: const Icon(Icons.timer_outlined, size: 18), label: Text(l.exerciseTimed)),
              ],
            ),
          ),
          SectionCard(
            title: l.exerciseMuscles,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.exercisePrimary, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final muscle in exercise.primaryMuscles)
                      Pill(l.muscle(muscle)),
                  ],
                ),
                if (exercise.secondaryMuscles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l.exerciseSecondary, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final muscle in exercise.secondaryMuscles)
                        Pill(l.muscle(muscle), color: theme.colorScheme.surfaceContainerHighest),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (exercise.instructions.isNotEmpty)
            SectionCard(
              title: l.exerciseForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < exercise.instructions.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 14, child: Text('${i + 1}')),
                          const SizedBox(width: 12),
                          Expanded(child: Text(exercise.instructions[i])),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          SectionCard(
            title: l.exerciseHistory,
            child: stats.isEmpty
                ? Text(l.exerciseNoHistory)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _Record(
                            label: l.exerciseBestWeight,
                            value: formatWeight(
                              stats.map((s) => s.bestWeightKg).reduce((a, b) => a > b ? a : b),
                              unit,
                            ),
                          ),
                          _Record(
                            label: l.exerciseBestOneRm,
                            value: formatWeight(
                              stats.map((s) => s.bestOneRepMaxKg).reduce((a, b) => a > b ? a : b),
                              unit,
                            ),
                          ),
                          _Record(label: l.exerciseSessions, value: '${stats.length}'),
                        ],
                      ),
                      if (stats.length > 1) ...[
                        const SizedBox(height: 16),
                        Text(l.exerciseOneRmTrend, style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        SimpleLineChart(
                          points: [
                            for (final s in stats) ChartPoint(s.date, unit.fromKg(s.bestOneRepMaxKg)),
                          ],
                          formatValue: (v) => formatNumber(v, decimals: 0),
                          formatDate: formatDateShort,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Record extends StatelessWidget {
  const _Record({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
