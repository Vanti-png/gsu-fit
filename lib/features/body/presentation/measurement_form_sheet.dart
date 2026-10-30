import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/body/application/body_providers.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';

Future<void> showMeasurementForm(BuildContext context, {BodyMeasurement? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => MeasurementFormSheet(existing: existing),
  );
}

class MeasurementFormSheet extends ConsumerStatefulWidget {
  const MeasurementFormSheet({super.key, this.existing});

  final BodyMeasurement? existing;

  @override
  ConsumerState<MeasurementFormSheet> createState() => _MeasurementFormSheetState();
}

class _MeasurementFormSheetState extends ConsumerState<MeasurementFormSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late DateTime _date;
  late final WeightUnit _unit;
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late final TextEditingController _fat;
  late final TextEditingController _chest;
  late final TextEditingController _waist;
  late final TextEditingController _arm;
  late final TextEditingController _leg;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _unit = ref.read(settingsProvider).weightUnit;
    String text(double? value) => value == null ? '' : formatInputNumber(value);
    _date = e?.date ?? DateTime.now();
    _weight = TextEditingController(text: e?.weightKg == null ? '' : text(_unit.fromKg(e!.weightKg!)));
    _height = TextEditingController(text: text(e?.heightCm));
    _fat = TextEditingController(text: text(e?.bodyFatPercent));
    _chest = TextEditingController(text: text(e?.chestCm));
    _waist = TextEditingController(text: text(e?.waistCm));
    _arm = TextEditingController(text: text(e?.armCm));
    _leg = TextEditingController(text: text(e?.legCm));
    _notes = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    for (final controller in [_weight, _height, _fat, _chest, _waist, _arm, _leg, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(String? value, double min, double max) {
    if (value == null || value.trim().isEmpty) return null;
    final number = parseDecimal(value);
    return number == null || number < min || number > max ? context.l10n.validationNumber : null;
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l = context.l10n;
    final weight = parseDecimal(_weight.text);
    final measurement = BodyMeasurement(
      id: widget.existing?.id ?? newId(),
      date: _date,
      weightKg: weight == null ? null : cleanDouble(_unit.toKg(weight)),
      heightCm: parseDecimal(_height.text),
      bodyFatPercent: parseDecimal(_fat.text),
      chestCm: parseDecimal(_chest.text),
      waistCm: parseDecimal(_waist.text),
      armCm: parseDecimal(_arm.text),
      legCm: parseDecimal(_leg.text),
      notes: _notes.text.trim(),
      createdAt: widget.existing?.createdAt,
    );
    final values = [
      measurement.weightKg,
      measurement.heightCm,
      measurement.bodyFatPercent,
      measurement.chestCm,
      measurement.waistCm,
      measurement.armCm,
      measurement.legCm,
    ];
    if (values.every((v) => v == null)) {
      showMessage(context, l.measurementEmpty);
      return;
    }
    try {
      await ref.read(bodyActionsProvider).saveMeasurement(measurement);
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
      title: l.measurementDeleteTitle,
      message: l.measurementDeleteMessage,
      confirmLabel: l.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(bodyActionsProvider).deleteMeasurement(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _field(TextEditingController controller, String label, String suffix, double min, double max) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: fieldDecoration(label, suffix: suffix),
      validator: (value) => _validate(value, min, max),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kgMin = _unit.fromKg(20);
    final kgMax = _unit.fromKg(350);
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
                    widget.existing == null ? l.measurementAddTitle : l.measurementEditTitle,
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatDate(_date)),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) setState(() => _date = picked);
              },
            ),
            Text(l.measurementHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_weight, l.measurementWeight, _unit.symbol, kgMin, kgMax)),
                const SizedBox(width: 12),
                Expanded(child: _field(_height, l.profileHeight, 'cm', 100, 250)),
              ],
            ),
            const SizedBox(height: 12),
            _field(_fat, l.measurementBodyFat, '%', 2, 70),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_chest, l.measurementChest, 'cm', 40, 200)),
                const SizedBox(width: 12),
                Expanded(child: _field(_waist, l.measurementWaist, 'cm', 40, 200)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_arm, l.measurementArm, 'cm', 10, 80)),
                const SizedBox(width: 12),
                Expanded(child: _field(_leg, l.measurementLeg, 'cm', 20, 120)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: fieldDecoration(l.commonNotes),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(l.commonSave)),
          ],
        ),
      ),
    );
  }
}
