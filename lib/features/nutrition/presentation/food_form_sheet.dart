import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/nutrition/application/nutrition_actions.dart';
import 'package:gsu_fit/features/nutrition/domain/nutrition.dart';

/// Guesses the meal from the time of day.
MealType mealForNow() {
  final hour = DateTime.now().hour;
  if (hour < 11) return MealType.breakfast;
  if (hour < 16) return MealType.lunch;
  if (hour < 21) return MealType.dinner;
  return MealType.snack;
}

Future<void> showFoodForm(
  BuildContext context, {
  required String day,
  FoodEntry? existing,
  MealType? meal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FoodFormSheet(day: day, existing: existing, meal: meal),
  );
}

class FoodFormSheet extends ConsumerStatefulWidget {
  const FoodFormSheet({super.key, required this.day, this.existing, this.meal});

  final String day;
  final FoodEntry? existing;
  final MealType? meal;

  @override
  ConsumerState<FoodFormSheet> createState() => _FoodFormSheetState();
}

class _FoodFormSheetState extends ConsumerState<FoodFormSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late MealType _meal;
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    String text(double? value) => value == null || value == 0 ? '' : formatInputNumber(value);
    _meal = e?.meal ?? widget.meal ?? mealForNow();
    _name = TextEditingController(text: e?.name ?? '');
    _calories = TextEditingController(text: text(e?.calories));
    _protein = TextEditingController(text: text(e?.proteinG));
    _carbs = TextEditingController(text: text(e?.carbsG));
    _fat = TextEditingController(text: text(e?.fatG));
  }

  @override
  void dispose() {
    for (final controller in [_name, _calories, _protein, _carbs, _fat]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fills calories from the macros (4/4/9 kcal per gram) when left empty.
  double _calorieValue() {
    final typed = parseDecimal(_calories.text);
    if (typed != null) return typed;
    return (parseDecimal(_protein.text) ?? 0) * 4 +
        (parseDecimal(_carbs.text) ?? 0) * 4 +
        (parseDecimal(_fat.text) ?? 0) * 9;
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l = context.l10n;
    final entry = FoodEntry(
      id: widget.existing?.id ?? newId(),
      day: widget.existing?.day ?? widget.day,
      meal: _meal,
      name: _name.text.trim(),
      calories: _calorieValue(),
      proteinG: parseDecimal(_protein.text) ?? 0,
      carbsG: parseDecimal(_carbs.text) ?? 0,
      fatG: parseDecimal(_fat.text) ?? 0,
      createdAt: widget.existing?.createdAt,
    );
    try {
      await ref.read(nutritionActionsProvider).saveFood(entry);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showMessage(context, l.errorSaveFailed);
    }
  }

  String? _number(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = parseDecimal(value);
    return number == null || number < 0 || number > 10000 ? context.l10n.validationNumber : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              widget.existing == null ? l.foodAddTitle : l.foodEditTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final meal in MealType.values)
                  ChoiceChip(
                    label: Text(l.meal(meal)),
                    selected: _meal == meal,
                    onSelected: (_) => setState(() => _meal = meal),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration(l.foodName, hint: l.foodNameHint),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? l.validationRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _calories,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDecoration(l.foodCalories, suffix: 'kcal', helper: l.foodCaloriesHint),
              validator: _number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _protein,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: fieldDecoration(l.foodProtein, suffix: 'g'),
                    validator: _number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _carbs,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: fieldDecoration(l.foodCarbs, suffix: 'g'),
                    validator: _number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _fat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: fieldDecoration(l.foodFat, suffix: 'g'),
                    validator: _number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(l.commonSave)),
          ],
        ),
      ),
    );
  }
}
