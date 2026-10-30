import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/cardio/application/cardio_providers.dart';
import 'package:gsu_fit/features/cardio/domain/calorie_calculator.dart';
import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';

IconData cardioIcon(CardioType type) => switch (type) {
      CardioType.running => Icons.directions_run,
      CardioType.walking => Icons.directions_walk,
      CardioType.cycling => Icons.directions_bike,
      CardioType.swimming => Icons.pool,
      CardioType.rowing => Icons.rowing,
      CardioType.elliptical => Icons.fitness_center,
      CardioType.jumpRope => Icons.sports_gymnastics,
      CardioType.hiking => Icons.hiking,
      CardioType.other => Icons.sports,
    };

Future<void> showCardioForm(BuildContext context, {CardioSession? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CardioFormSheet(existing: existing),
  );
}

class CardioFormSheet extends ConsumerStatefulWidget {
  const CardioFormSheet({super.key, this.existing});

  final CardioSession? existing;

  @override
  ConsumerState<CardioFormSheet> createState() => _CardioFormSheetState();
}

class _CardioFormSheetState extends ConsumerState<CardioFormSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late CardioType _type;
  late DateTime _start;
  late final TextEditingController _minutes;
  late final TextEditingController _distance;
  late final TextEditingController _calories;
  late final TextEditingController _notes;
  bool _caloriesEdited = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? CardioType.running;
    _start = e?.startedAt ?? DateTime.now();
    _minutes = TextEditingController(text: e == null ? '30' : '${e.duration.inMinutes}');
    _distance = TextEditingController(
      text: e?.distanceKm == null ? '' : formatInputNumber(e!.distanceKm!),
    );
    _calories = TextEditingController(text: e == null ? '' : formatInputNumber(e.calories.round()));
    _notes = TextEditingController(text: e?.notes ?? '');
    _caloriesEdited = e != null;
    if (e == null) WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
  }

  @override
  void dispose() {
    _minutes.dispose();
    _distance.dispose();
    _calories.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _estimate({bool force = false}) {
    if (_caloriesEdited && !force) return;
    final weight = ref.read(profileProvider).dataOrNull?.weightKg ?? 70;
    final minutes = parseInt(_minutes.text) ?? 0;
    final kcal = CalorieCalculator.estimate(
      type: _type,
      duration: Duration(minutes: minutes),
      weightKg: weight,
      distanceKm: parseDecimal(_distance.text),
    );
    _calories.text = formatInputNumber(kcal.round());
    if (force) _caloriesEdited = false;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (!mounted) return;
    setState(() {
      _start = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _start.hour,
        time?.minute ?? _start.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l = context.l10n;
    final session = CardioSession(
      id: widget.existing?.id ?? newId(),
      type: _type,
      startedAt: _start,
      durationSeconds: (parseInt(_minutes.text) ?? 0) * 60,
      distanceKm: parseDecimal(_distance.text),
      calories: parseDecimal(_calories.text) ?? 0,
      notes: _notes.text.trim(),
      createdAt: widget.existing?.createdAt,
    );
    try {
      await ref.read(cardioRepositoryProvider).save(session);
      ref.invalidate(cardioSessionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showMessage(context, l.errorSaveFailed);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await confirmDialog(
      context,
      title: l.cardioDeleteTitle,
      message: l.cardioDeleteMessage,
      confirmLabel: l.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(cardioRepositoryProvider).delete(existing.id);
    ref.invalidate(cardioSessionsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final minutes = parseInt(_minutes.text) ?? 0;
    final pace = _type == CardioType.running || _type == CardioType.walking
        ? CalorieCalculator.pacePerKm(Duration(minutes: minutes), parseDecimal(_distance.text))
        : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null ? l.cardioAddTitle : l.cardioEditTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.existing != null)
                  IconButton(
                    tooltip: l.commonDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final type in CardioType.values)
                  ChoiceChip(
                    avatar: Icon(cardioIcon(type), size: 18),
                    label: Text(l.cardioType(type)),
                    selected: _type == type,
                    onSelected: (_) => setState(() {
                      _type = type;
                      _estimate();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatDateTime(_start)),
              trailing: const Icon(Icons.edit),
              onTap: _pickDate,
            ),
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: fieldDecoration(l.cardioDuration, suffix: l.unitMinutesShort),
              validator: (value) {
                final m = parseInt(value);
                return m == null || m <= 0 || m > 1440 ? l.validationDuration : null;
              },
              onChanged: (_) => setState(_estimate),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _distance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDecoration(l.cardioDistance, suffix: 'km', helper: l.commonOptional),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final d = parseDecimal(value);
                return d == null || d < 0 || d > 1000 ? l.validationNumber : null;
              },
              onChanged: (_) => setState(_estimate),
            ),
            if (pace != null) ...[
              const SizedBox(height: 4),
              Text(l.cardioPace(formatClock(pace))),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _calories,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.cardioCalories,
                suffixText: 'kcal',
                helperText: l.cardioCaloriesHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: l.cardioRecalculate,
                  icon: const Icon(Icons.calculate_outlined),
                  onPressed: () => setState(() => _estimate(force: true)),
                ),
              ),
              onChanged: (_) => _caloriesEdited = true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: fieldDecoration(l.commonNotes),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(l.commonSave)),
          ],
        ),
      ),
    );
  }
}
