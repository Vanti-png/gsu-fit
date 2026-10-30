import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/features/exercises/presentation/library_screen.dart';
import 'package:gsu_fit/features/home/presentation/home_screen.dart';
import 'package:gsu_fit/features/nutrition/presentation/nutrition_screen.dart';
import 'package:gsu_fit/features/programs/presentation/programs_screen.dart';
import 'package:gsu_fit/features/progress/presentation/progress_screen.dart';
import 'package:gsu_fit/features/workout/application/active_workout_controller.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/features/workout/presentation/active_workout_screen.dart';

final homeTabProvider = NotifierProvider<HomeTabController, int>(HomeTabController.new);

class HomeTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

/// Bottom navigation with the five main sections. Tabs keep their state
/// (IndexedStack) so switching back does not lose scroll position.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final index = ref.watch(homeTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          HomeScreen(),
          ProgramsScreen(),
          LibraryScreen(),
          ProgressScreen(),
          NutritionScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _OngoingWorkoutBanner(),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: ref.read(homeTabProvider.notifier).select,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: l.navHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.event_note_outlined),
                selectedIcon: const Icon(Icons.event_note),
                label: l.navPrograms,
              ),
              NavigationDestination(
                icon: const Icon(Icons.fitness_center_outlined),
                selectedIcon: const Icon(Icons.fitness_center),
                label: l.navLibrary,
              ),
              NavigationDestination(
                icon: const Icon(Icons.insights_outlined),
                selectedIcon: const Icon(Icons.insights),
                label: l.navProgress,
              ),
              NavigationDestination(
                icon: const Icon(Icons.restaurant_outlined),
                selectedIcon: const Icon(Icons.restaurant),
                label: l.navNutrition,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reminds the user of a session that is still open (also after the app
/// was closed) and takes them back to it.
class _OngoingWorkoutBanner extends ConsumerWidget {
  const _OngoingWorkoutBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final active = ref.watch(activeWorkoutProvider);
    final stored = ref.watch(unfinishedWorkoutProvider).dataOrNull;
    final workout = active?.workout ?? stored;
    if (workout == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: InkWell(
        onTap: () => openActiveWorkout(context, ref, resume: workout),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${l.workoutOngoing}: ${workout.name} · '
                  '${formatClock(DateTime.now().difference(workout.startedAt))}',
                  style: TextStyle(color: scheme.onSecondaryContainer),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l.workoutResume,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
