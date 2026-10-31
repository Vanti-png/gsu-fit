import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';
import 'package:gsu_fit/features/profile/presentation/profile_fields.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final ProfileDraft _draft = ProfileDraft.from(widget.profile);

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l = context.l10n;
    final updated = widget.profile.copyWith(
      name: _draft.name,
      age: _draft.age,
      heightCm: _draft.heightCm,
      weightKg: _draft.weightKg,
      sex: _draft.sex,
      goal: _draft.goal,
      experience: _draft.experience,
      daysPerWeek: _draft.daysPerWeek,
    );
    try {
      await ref.read(profileRepositoryProvider).save(updated);
      ref.invalidate(profileProvider);
      if (!mounted) return;
      showMessage(context, l.profileSaved);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showMessage(context, l.errorSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final unit = ref.watch(settingsProvider.select((s) => s.weightUnit));
    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: ReadableWidth(child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BodyInfoFields(draft: _draft, unit: unit),
            const SizedBox(height: 24),
            Text(l.onboardingGoalTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GoalPicker(value: _draft.goal, onChanged: (goal) => setState(() => _draft.goal = goal)),
            const SizedBox(height: 24),
            Text(l.onboardingLevelTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ExperiencePicker(
              experience: _draft.experience,
              daysPerWeek: _draft.daysPerWeek,
              onExperience: (level) => setState(() => _draft.experience = level),
              onDays: (days) => setState(() => _draft.daysPerWeek = days),
            ),
            const SizedBox(height: 8),
            Text(l.profileProgramNote, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(l.commonSave)),
          ],
        ),
      )),
    );
  }
}
