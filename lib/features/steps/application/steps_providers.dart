import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/steps/data/steps_service.dart';

final stepsServiceProvider = Provider<StepsService>((ref) => StepsService());

/// Null while the feature is turned off in settings.
final todayStepsProvider = FutureProvider<StepsResult?>((ref) async {
  final enabled = ref.watch(settingsProvider.select((s) => s.stepsEnabled));
  if (!enabled) return null;
  return ref.watch(stepsServiceProvider).todaySteps();
});
