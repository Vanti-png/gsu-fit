import 'package:flutter/material.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';

/// Large tappable card used for single-choice questions (goal, level).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: selected ? scheme.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 32, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData goalIcon(FitnessGoal goal) => switch (goal) {
      FitnessGoal.muscleGain => Icons.fitness_center,
      FitnessGoal.weightLoss => Icons.local_fire_department,
      FitnessGoal.endurance => Icons.directions_run,
      FitnessGoal.generalHealth => Icons.favorite,
    };

IconData levelIcon(ExperienceLevel level) => switch (level) {
      ExperienceLevel.beginner => Icons.looks_one,
      ExperienceLevel.intermediate => Icons.looks_two,
      ExperienceLevel.advanced => Icons.looks_3,
    };

/// Editable copy of the profile fields shared by onboarding and the
/// profile screen. Weight is entered in the chosen [unit].
class ProfileDraft {
  ProfileDraft({
    this.name = '',
    this.age = 25,
    this.heightCm = 170,
    this.weightKg = 70,
    this.sex = Sex.unspecified,
    this.goal = FitnessGoal.generalHealth,
    this.experience = ExperienceLevel.beginner,
    this.daysPerWeek = 3,
  });

  factory ProfileDraft.from(UserProfile profile) => ProfileDraft(
        name: profile.name,
        age: profile.age,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
        sex: profile.sex,
        goal: profile.goal,
        experience: profile.experience,
        daysPerWeek: profile.daysPerWeek,
      );

  String name;
  int age;
  double heightCm;
  double weightKg;
  Sex sex;
  FitnessGoal goal;
  ExperienceLevel experience;
  int daysPerWeek;
}

/// Name, age, sex, height and weight inputs with validation.
class BodyInfoFields extends StatefulWidget {
  const BodyInfoFields({super.key, required this.draft, required this.unit});

  final ProfileDraft draft;
  final WeightUnit unit;

  @override
  State<BodyInfoFields> createState() => _BodyInfoFieldsState();
}

class _BodyInfoFieldsState extends State<BodyInfoFields> {
  late final TextEditingController _name =
      TextEditingController(text: widget.draft.name);
  late final TextEditingController _age =
      TextEditingController(text: '${widget.draft.age}');
  late final TextEditingController _height =
      TextEditingController(text: formatInputNumber(widget.draft.heightCm));
  late final TextEditingController _weight =
      TextEditingController(text: formatInputNumber(widget.unit.fromKg(widget.draft.weightKg)));

  @override
  void didUpdateWidget(covariant BodyInfoFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unit != widget.unit) {
      _weight.text = formatInputNumber(widget.unit.fromKg(widget.draft.weightKg));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final draft = widget.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _name,
          decoration: fieldDecoration(l.profileName, hint: l.profileNameHint),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) => draft.name = value.trim(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _age,
          decoration: fieldDecoration(l.profileAge),
          keyboardType: TextInputType.number,
          validator: (value) {
            final age = parseInt(value);
            return age == null || age < 13 || age > 100 ? l.validationAge : null;
          },
          onChanged: (value) {
            final age = parseInt(value);
            if (age != null) draft.age = age;
          },
        ),
        const SizedBox(height: 16),
        Text(l.profileSex, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sex in Sex.values)
              ChoiceChip(
                label: Text(l.sex(sex)),
                selected: draft.sex == sex,
                onSelected: (_) => setState(() => draft.sex = sex),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l.profileSexHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _height,
          decoration: fieldDecoration(l.profileHeight, suffix: 'cm'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final height = parseDecimal(value);
            return height == null || height < 100 || height > 250 ? l.validationHeight : null;
          },
          onChanged: (value) {
            final height = parseDecimal(value);
            if (height != null) draft.heightCm = height;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _weight,
          decoration: fieldDecoration(l.profileWeight, suffix: widget.unit.symbol),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final weight = parseDecimal(value);
            if (weight == null) return l.validationWeight;
            final kg = widget.unit.toKg(weight);
            return kg < 30 || kg > 300 ? l.validationWeight : null;
          },
          onChanged: (value) {
            final weight = parseDecimal(value);
            if (weight != null) draft.weightKg = widget.unit.toKg(weight);
          },
        ),
      ],
    );
  }
}

/// Goal choice cards.
class GoalPicker extends StatelessWidget {
  const GoalPicker({super.key, required this.value, required this.onChanged});

  final FitnessGoal value;
  final ValueChanged<FitnessGoal> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        for (final goal in FitnessGoal.values)
          ChoiceCard(
            title: l.goal(goal),
            subtitle: l.goalHint(goal),
            icon: goalIcon(goal),
            selected: value == goal,
            onTap: () => onChanged(goal),
          ),
      ],
    );
  }
}

/// Experience cards plus the training days selector.
class ExperiencePicker extends StatelessWidget {
  const ExperiencePicker({
    super.key,
    required this.experience,
    required this.daysPerWeek,
    required this.onExperience,
    required this.onDays,
  });

  final ExperienceLevel experience;
  final int daysPerWeek;
  final ValueChanged<ExperienceLevel> onExperience;
  final ValueChanged<int> onDays;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final level in ExperienceLevel.values)
          ChoiceCard(
            title: l.level(level),
            subtitle: l.levelHint(level),
            icon: levelIcon(level),
            selected: experience == level,
            onTap: () => onExperience(level),
          ),
        const SizedBox(height: 16),
        Text(l.profileDaysPerWeek, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var days = 2; days <= 6; days++)
              ChoiceChip(
                label: Text(l.daysCount('$days')),
                selected: daysPerWeek == days,
                onSelected: (_) => onDays(days),
              ),
          ],
        ),
      ],
    );
  }
}
