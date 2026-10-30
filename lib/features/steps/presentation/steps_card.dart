import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/steps/application/steps_providers.dart';
import 'package:gsu_fit/features/steps/data/steps_service.dart';

/// Turns step counting on: asks Health Connect for permission first.
Future<bool> enableSteps(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final service = ref.read(stepsServiceProvider);
  final granted = await service.requestPermission();
  if (!context.mounted) return false;
  if (!granted) {
    showMessage(context, l.stepsPermissionDenied);
    return false;
  }
  await ref.read(settingsProvider.notifier).change((s) => s.copyWith(stepsEnabled: true));
  ref.invalidate(todayStepsProvider);
  return true;
}

class StepsCard extends ConsumerWidget {
  const StepsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final goal = ref.watch(settingsProvider.select((s) => s.stepGoal));
    final steps = ref.watch(todayStepsProvider);

    return SectionCard(
      title: l.stepsTitle,
      trailing: IconButton(
        tooltip: l.commonRefresh,
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(todayStepsProvider),
      ),
      child: steps.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => Text(l.stepsError),
        data: (result) {
          if (result == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.stepsIntro),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => enableSteps(context, ref),
                  icon: const Icon(Icons.directions_walk),
                  label: Text(l.stepsConnect),
                ),
              ],
            );
          }
          switch (result.status) {
            case StepsStatus.ok:
              final fraction = goal <= 0 ? 0.0 : result.steps / goal;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.stepsToday(formatNumber(result.steps, decimals: 0)),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  ProgressBar(value: fraction),
                  const SizedBox(height: 4),
                  Text(l.stepsGoal(formatNumber(goal, decimals: 0))),
                ],
              );
            case StepsStatus.needsPermission:
              return _Action(
                message: l.stepsNeedsPermission,
                label: l.stepsGrant,
                onPressed: () => enableSteps(context, ref),
              );
            case StepsStatus.notInstalled:
            case StepsStatus.needsUpdate:
              return _Action(
                message: result.status == StepsStatus.notInstalled
                    ? l.stepsNotInstalled
                    : l.stepsNeedsUpdate,
                label: l.stepsInstall,
                onPressed: () => ref.read(stepsServiceProvider).installHealthConnect(),
              );
            case StepsStatus.unavailable:
              return Text(l.stepsUnavailable);
            case StepsStatus.error:
              return Text(l.stepsError);
          }
        },
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.message, required this.label, required this.onPressed});

  final String message;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: onPressed, child: Text(label)),
      ],
    );
  }
}
