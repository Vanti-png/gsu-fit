import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/body/application/body_providers.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';
import 'package:gsu_fit/features/profile/presentation/profile_fields.dart';
import 'package:gsu_fit/features/programs/application/program_providers.dart';
import 'package:gsu_fit/features/programs/domain/program_generator.dart';
import 'package:gsu_fit/features/programs/presentation/program_labels.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';

/// Welcome page followed by a four-step profile setup.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  final GlobalKey<FormState> _bodyForm = GlobalKey<FormState>();
  final ProfileDraft _draft = ProfileDraft();
  WeightUnit _unit = WeightUnit.kg;
  int _page = 0;
  bool _saving = false;

  static const int _pageCount = 5;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 1 && !(_bodyForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _back() {
    _pages.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finish({required bool createProgram}) async {
    setState(() => _saving = true);
    final l = context.l10n;
    try {
      final profile = UserProfile(
        id: newId(),
        name: _draft.name,
        age: _draft.age,
        heightCm: _draft.heightCm,
        weightKg: _draft.weightKg,
        sex: _draft.sex,
        goal: _draft.goal,
        experience: _draft.experience,
        daysPerWeek: _draft.daysPerWeek,
      );
      await ref.read(settingsProvider.notifier).change((s) => s.copyWith(
            weightUnit: _unit,
            workoutReminderDays: ProgramGenerator.defaultWeekdays(profile.daysPerWeek),
          ));
      await ref.read(bodyRepositoryProvider).saveMeasurement(BodyMeasurement(
            id: newId(),
            date: DateTime.now(),
            weightKg: profile.weightKg,
            heightCm: profile.heightCm,
          ));
      if (createProgram) {
        final repository = ref.read(programRepositoryProvider);
        final program = ProgramGenerator(labels: programLabels(l)).generate(profile);
        await repository.saveFull(program.copyWith(isActive: true));
        await repository.setActive(program.id);
      }
      await ref.read(profileRepositoryProvider).save(profile);
      ref.invalidate(programsProvider);
      ref.invalidate(measurementsProvider);
      // RootGate swaps this screen for the main app.
      ref.invalidate(profileProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, l.errorSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: ReadableWidth(maxWidth: 560, child: SafeArea(
        child: Column(
          children: [
            if (_page > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l.commonBack,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _saving ? null : _back,
                    ),
                    Expanded(child: ProgressBar(value: _page / (_pageCount - 1), height: 6)),
                  ],
                ),
              ),
            // The key keeps the same PageView when the header and footer
            // appear after the welcome page; without it Flutter rebuilds
            // the PageView, which jumps back to the first page.
            Expanded(
              key: const ValueKey('onboarding-pages'),
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  _WelcomePage(onStart: _next),
                  _StepPage(
                    title: l.onboardingBodyTitle,
                    subtitle: l.onboardingBodySubtitle,
                    child: Form(
                      key: _bodyForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppleSegmented<WeightUnit>(
                            value: _unit,
                            segments: {WeightUnit.kg: l.unitKg, WeightUnit.lb: l.unitLb},
                            onChanged: (unit) => setState(() => _unit = unit),
                          ),
                          const SizedBox(height: 16),
                          BodyInfoFields(draft: _draft, unit: _unit),
                        ],
                      ),
                    ),
                  ),
                  _StepPage(
                    title: l.onboardingGoalTitle,
                    subtitle: l.onboardingGoalSubtitle,
                    child: GoalPicker(
                      value: _draft.goal,
                      onChanged: (goal) => setState(() => _draft.goal = goal),
                    ),
                  ),
                  _StepPage(
                    title: l.onboardingLevelTitle,
                    subtitle: l.onboardingLevelSubtitle,
                    child: ExperiencePicker(
                      experience: _draft.experience,
                      daysPerWeek: _draft.daysPerWeek,
                      onExperience: (level) => setState(() => _draft.experience = level),
                      onDays: (days) => setState(() => _draft.daysPerWeek = days),
                    ),
                  ),
                  _SummaryPage(draft: _draft),
                ],
              ),
            ),
            if (_page > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _page < _pageCount - 1
                    ? SizedBox(
                        width: double.infinity,
                        child: FilledButton(onPressed: _next, child: Text(l.commonContinue)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: _saving ? null : () => _finish(createProgram: true),
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: Text(l.onboardingCreateProgram),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _saving ? null : () => _finish(createProgram: false),
                            child: Text(l.onboardingSkipProgram),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      )),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          const Center(child: AppMark(size: 96)),
          const SizedBox(height: 24),
          Text(
            l.appTitle,
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(l.onboardingTagline, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          for (final (icon, text) in [
            (Icons.event_note, l.onboardingFeaturePrograms),
            (Icons.show_chart, l.onboardingFeatureProgress),
            (Icons.lock_outline, l.onboardingFeaturePrivacy),
          ])
            ListTile(
              leading: Icon(icon, color: theme.colorScheme.primary),
              title: Text(text),
            ),
          const SizedBox(height: 32),
          FilledButton(onPressed: onStart, child: Text(l.onboardingStart)),
        ],
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _SummaryPage extends StatelessWidget {
  const _SummaryPage({required this.draft});

  final ProfileDraft draft;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final split = ProgramGenerator.recommendSplit(draft.experience, draft.daysPerWeek);
    final days = ProgramGenerator.templatesFor(split, draft.daysPerWeek).length;
    return _StepPage(
      title: l.onboardingSummaryTitle,
      subtitle: l.onboardingSummarySubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: l.onboardingRecommended,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.split(split), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(l.programDaysPerWeek('$days')),
                const SizedBox(height: 12),
                Text(l.programDescription(l.split(split), l.goal(draft.goal))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(goalIcon(draft.goal)),
            title: Text(l.goal(draft.goal)),
            subtitle: Text(l.level(draft.experience)),
          ),
          ListTile(
            leading: const Icon(Icons.edit_calendar),
            title: Text(l.onboardingEditLater),
          ),
        ],
      ),
    );
  }
}
