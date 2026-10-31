import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/theme/app_theme.dart';
import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/exercises/presentation/library_screen.dart';
import 'package:gsu_fit/features/home/presentation/home_screen.dart';
import 'package:gsu_fit/features/nutrition/presentation/nutrition_screen.dart';
import 'package:gsu_fit/features/programs/presentation/programs_screen.dart';
import 'package:gsu_fit/features/progress/presentation/progress_screen.dart';
import 'package:gsu_fit/features/settings/presentation/settings_screen.dart';
import 'package:gsu_fit/features/workout/application/active_workout_controller.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/features/workout/presentation/active_workout_screen.dart';

final homeTabProvider = NotifierProvider<HomeTabController, int>(HomeTabController.new);

class HomeTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

/// Width from which the window gets a macOS-style sidebar instead of the
/// bottom tab bar.
const double sidebarBreakpoint = 900;

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

List<_Destination> _destinations(AppLocalizations l) => [
      _Destination(CupertinoIcons.house, CupertinoIcons.house_fill, l.navHome),
      _Destination(CupertinoIcons.calendar, CupertinoIcons.calendar, l.navPrograms),
      _Destination(CupertinoIcons.book, CupertinoIcons.book_fill, l.navLibrary),
      _Destination(CupertinoIcons.chart_bar, CupertinoIcons.chart_bar_fill, l.navProgress),
      _Destination(Icons.restaurant_outlined, Icons.restaurant, l.navNutrition),
    ];

const List<LogicalKeyboardKey> _tabKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
];

/// The five main sections. Phones get an iOS tab bar; wide windows get a
/// sidebar with keyboard shortcuts (⌥1…⌥5, ⌥, for settings). Tabs keep
/// their state (IndexedStack), so switching back keeps the scroll position.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    final index = ref.watch(homeTabProvider);
    final select = ref.read(homeTabProvider.notifier).select;
    final destinations = _destinations(l);
    final wide = MediaQuery.sizeOf(context).width >= sidebarBreakpoint;

    final tabs = IndexedStack(
      index: index,
      children: const [
        HomeScreen(),
        ProgramsScreen(),
        LibraryScreen(),
        ProgressScreen(),
        NutritionScreen(),
      ],
    );

    final Widget shell;
    if (wide) {
      shell = Scaffold(
        body: Row(
          children: [
            _Sidebar(
              destinations: destinations,
              index: index,
              onSelect: select,
              onSettings: () => openSettings(context),
            ),
            Container(width: 0.5, color: palette.border),
            Expanded(
              child: Column(
                children: [
                  const _OngoingWorkoutBanner(),
                  Expanded(child: ReadableWidth(maxWidth: 1040, child: tabs)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      shell = Scaffold(
        body: tabs,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _OngoingWorkoutBanner(),
            CupertinoTabBar(
              currentIndex: index,
              onTap: select,
              height: 54,
              activeColor: palette.accent,
              inactiveColor: palette.textSecondary,
              backgroundColor: palette.bar,
              border: Border(top: BorderSide(color: palette.border, width: 0.5)),
              items: [
                for (final destination in destinations)
                  BottomNavigationBarItem(
                    icon: Icon(destination.icon),
                    activeIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < _tabKeys.length; i++)
          SingleActivator(_tabKeys[i], alt: true): () => select(i),
        const SingleActivator(LogicalKeyboardKey.comma, alt: true): () => openSettings(context),
      },
      child: Focus(autofocus: true, child: shell),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.index,
    required this.onSelect,
    required this.onSettings,
  });

  final List<_Destination> destinations;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    return Container(
      width: 248,
      color: palette.sidebar,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 16, 18),
              child: Row(
                children: [
                  const AppMark(size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.appTitle, style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < destinations.length; i++)
              _SidebarItem(
                icon: i == index ? destinations[i].selectedIcon : destinations[i].icon,
                label: destinations[i].label,
                hint: KbdHint.alt('${i + 1}'),
                selected: i == index,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            _SidebarItem(
              icon: CupertinoIcons.gear,
              label: l.settingsTitle,
              hint: KbdHint.alt(','),
              selected: false,
              onTap: onSettings,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? palette.selection : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: selected ? palette.accent : palette.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: text?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  KbdHint(hint),
                ],
              ),
            ),
          ),
        ),
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
    final palette = context.palette;
    final active = ref.watch(activeWorkoutProvider);
    final stored = ref.watch(unfinishedWorkoutProvider).dataOrNull;
    final workout = active?.workout ?? stored;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: workout == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: palette.accentTint,
              child: InkWell(
                onTap: () => openActiveWorkout(context, ref, resume: workout),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.timer, color: palette.accentText, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${l.workoutOngoing}: ${workout.name} · '
                          '${formatClock(DateTime.now().difference(workout.startedAt))}',
                          style: TextStyle(color: palette.accentText),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        l.workoutResume,
                        style: TextStyle(color: palette.accentText, fontWeight: FontWeight.w600),
                      ),
                      Icon(CupertinoIcons.chevron_right, color: palette.accentText, size: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
