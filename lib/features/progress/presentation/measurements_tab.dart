import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/body/application/body_providers.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';
import 'package:gsu_fit/features/body/presentation/measurement_form_sheet.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';

class MeasurementsTab extends ConsumerWidget {
  const MeasurementsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final measurements = ref.watch(measurementsProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.weightUnit));
    final profileHeight = ref.watch(profileProvider).dataOrNull?.heightCm;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'measurement-fab',
        onPressed: () => showMeasurementForm(context),
        icon: const Icon(Icons.add),
        label: Text(l.measurementAddTitle),
      ),
      body: AsyncValueView<List<BodyMeasurement>>(
        value: measurements,
        onRetry: () => ref.invalidate(measurementsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.straighten,
              title: l.measurementsEmpty,
              message: l.measurementsEmptyHint,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final m = list[index];
              final bmi = m.bmi(fallbackHeightCm: profileHeight);
              final values = <String>[
                if (m.weightKg != null) '${l.measurementWeight}: ${formatWeight(m.weightKg!, unit)}',
                if (bmi != null) '${l.measurementBmi}: ${formatNumber(bmi)}',
                for (final field in MeasurementField.values)
                  if (field != MeasurementField.weight && m.valueOf(field) != null)
                    '${l.measurementField(field)}: ${formatNumber(m.valueOf(field)!)}'
                        '${field == MeasurementField.bodyFat ? ' %' : ' cm'}',
              ];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(formatDate(m.date)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final value in values) Chip(label: Text(value))],
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => showMeasurementForm(context, existing: m),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
