import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/nutrition/application/nutrition_actions.dart';
import 'package:gsu_fit/features/nutrition/application/nutrition_providers.dart';
import 'package:gsu_fit/features/nutrition/domain/nutrition.dart';
import 'package:gsu_fit/features/nutrition/presentation/food_form_sheet.dart';
import 'package:gsu_fit/features/settings/presentation/settings_screen.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  DateTime _day = dateOnly(DateTime.now());

  void _shift(int days) {
    final next = DateTime(_day.year, _day.month, _day.day + days);
    if (next.isAfter(dateOnly(DateTime.now()))) return;
    setState(() => _day = next);
  }

  Future<void> _customWater(String key) async {
    final l = context.l10n;
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.waterCustomTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: fieldDecoration(l.waterAmount, suffix: 'ml'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(parseInt(controller.text)),
            child: Text(l.commonAdd),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || amount > 5000) return;
    await ref.read(nutritionActionsProvider).addWater(key, amount);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final key = dayKey(_day);
    final isToday = isSameDay(_day, DateTime.now());
    final food = ref.watch(foodEntriesProvider(key));
    final water = ref.watch(waterEntriesProvider(key)).dataOrNull ?? const [];
    final targets = ref.watch(nutritionTargetsProvider);
    final actions = ref.read(nutritionActionsProvider);
    final waterTotal = water.fold(0, (sum, e) => sum + e.amountMl);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.nutritionTitle),
        actions: [SettingsAction(onOpen: () => openSettings(context))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nutrition-fab',
        onPressed: () => showFoodForm(context, day: key),
        icon: const Icon(Icons.add),
        label: Text(l.foodAddTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: l.commonPreviousDay,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: Text(
                    isToday ? l.commonToday : formatDateWithWeekday(_day),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l.commonNextDay,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isToday ? null : () => _shift(1),
                ),
              ],
            ),
          ),
          SectionCard(
            title: l.waterTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  targets == null
                      ? l.waterTotal(formatNumber(waterTotal, decimals: 0))
                      : l.waterProgress(
                          formatNumber(waterTotal, decimals: 0),
                          formatNumber(targets.waterMl, decimals: 0),
                        ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ProgressBar(
                  value: targets == null || targets.waterMl == 0 ? 0 : waterTotal / targets.waterMl,
                  color: Colors.lightBlue,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amount in const [200, 250, 330, 500])
                      FilledButton.tonal(
                        onPressed: () => actions.addWater(key, amount),
                        child: Text('+$amount ml'),
                      ),
                    OutlinedButton(
                      onPressed: () => _customWater(key),
                      child: Text(l.waterCustom),
                    ),
                  ],
                ),
                if (water.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => actions.deleteWater(water.last),
                      icon: const Icon(Icons.undo),
                      label: Text(l.waterUndoLast('${water.last.amountMl}')),
                    ),
                  ),
                ],
              ],
            ),
          ),
          AsyncValueView<List<FoodEntry>>(
            value: food,
            onRetry: () => ref.invalidate(foodEntriesProvider(key)),
            data: (entries) => _FoodSection(entries: entries, targets: targets, day: key),
          ),
        ],
      ),
    );
  }
}

class _FoodSection extends ConsumerWidget {
  const _FoodSection({required this.entries, required this.targets, required this.day});

  final List<FoodEntry> entries;
  final NutritionTargets? targets;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final totals = NutritionTotals.of(entries);
    final goal = targets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: l.nutritionCalories,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                goal == null
                    ? l.kcalValue(formatNumber(totals.calories, decimals: 0))
                    : l.caloriesProgress(
                        formatNumber(totals.calories, decimals: 0),
                        formatNumber(goal.calories, decimals: 0),
                      ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ProgressBar(value: goal == null ? 0 : totals.calories / goal.calories),
              const SizedBox(height: 16),
              _MacroRow(
                label: l.foodProtein,
                value: totals.proteinG,
                target: goal?.proteinG,
                color: Colors.redAccent,
              ),
              _MacroRow(
                label: l.foodCarbs,
                value: totals.carbsG,
                target: goal?.carbsG,
                color: Colors.amber,
              ),
              _MacroRow(
                label: l.foodFat,
                value: totals.fatG,
                target: goal?.fatG,
                color: Colors.purpleAccent,
              ),
              if (goal != null) ...[
                const SizedBox(height: 8),
                Text(l.nutritionTargetsNote, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        for (final meal in MealType.values)
          SectionCard(
            title: l.meal(meal),
            trailing: IconButton(
              tooltip: l.foodAddTitle,
              icon: const Icon(Icons.add),
              onPressed: () => showFoodForm(context, day: day, meal: meal),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: _MealEntries(entries: entries.where((e) => e.meal == meal).toList()),
          ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.value, required this.target, required this.color});

  final String label;
  final double value;
  final int? target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final goal = target;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            goal == null
                ? '$label: ${formatNumber(value, decimals: 0)} g'
                : '$label: ${formatNumber(value, decimals: 0)} / $goal g',
          ),
          const SizedBox(height: 4),
          ProgressBar(value: goal == null || goal == 0 ? 0 : value / goal, color: color, height: 8),
        ],
      ),
    );
  }
}

class _MealEntries extends ConsumerStatefulWidget {
  const _MealEntries({required this.entries});

  final List<FoodEntry> entries;

  @override
  ConsumerState<_MealEntries> createState() => _MealEntriesState();
}

class _MealEntriesState extends ConsumerState<_MealEntries> {
  // A dismissed row must leave the tree at once, before the provider has
  // reloaded, so it is hidden locally first.
  final Set<String> _hidden = {};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final entries = widget.entries.where((e) => !_hidden.contains(e.id)).toList();
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(l.foodEmpty, style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Column(
      children: [
        for (final entry in entries)
          Dismissible(
            key: ValueKey(entry.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Icon(Icons.delete_outline),
            ),
            onDismissed: (_) {
              final actions = ref.read(nutritionActionsProvider);
              setState(() => _hidden.add(entry.id));
              actions.deleteFood(entry);
              showMessage(
                context,
                l.foodDeleted(entry.name),
                action: SnackBarAction(
                  label: l.commonUndo,
                  onPressed: () async {
                    await actions.saveFood(entry);
                    if (mounted) setState(() => _hidden.remove(entry.id));
                  },
                ),
              );
            },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.name),
              subtitle: Text(l.macroSummary(
                formatNumber(entry.proteinG, decimals: 0),
                formatNumber(entry.carbsG, decimals: 0),
                formatNumber(entry.fatG, decimals: 0),
              )),
              trailing: Text(l.kcalValue(formatNumber(entry.calories, decimals: 0))),
              onTap: () => showFoodForm(context, day: entry.day, existing: entry),
            ),
          ),
      ],
    );
  }
}
