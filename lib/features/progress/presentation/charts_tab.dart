import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/l10n/labels.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/body/application/body_providers.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';
import 'package:gsu_fit/features/exercises/application/exercise_providers.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/workout/application/workout_providers.dart';
import 'package:gsu_fit/features/workout/domain/workout_stats.dart';

enum ChartRange { month, quarter, year, all }

enum StrengthMetric { oneRepMax, bestWeight, volume }

class ChartsTab extends ConsumerStatefulWidget {
  const ChartsTab({super.key});

  @override
  ConsumerState<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends ConsumerState<ChartsTab> {
  ChartRange _range = ChartRange.quarter;
  MeasurementField _field = MeasurementField.waist;
  StrengthMetric _metric = StrengthMetric.oneRepMax;
  String? _exerciseId;

  DateTime? get _since {
    final now = DateTime.now();
    return switch (_range) {
      ChartRange.month => DateTime(now.year, now.month - 1, now.day),
      ChartRange.quarter => DateTime(now.year, now.month - 3, now.day),
      ChartRange.year => DateTime(now.year - 1, now.month, now.day),
      ChartRange.all => null,
    };
  }

  List<ChartPoint> _inRange(List<ChartPoint> points) {
    final since = _since;
    final filtered = since == null ? points : points.where((p) => !p.date.isBefore(since)).toList();
    return filtered..sort((a, b) => a.date.compareTo(b.date));
  }

  String _rangeLabel(AppLocalizations l, ChartRange range) => switch (range) {
        ChartRange.month => l.rangeMonth,
        ChartRange.quarter => l.rangeQuarter,
        ChartRange.year => l.rangeYear,
        ChartRange.all => l.rangeAll,
      };

  String _metricLabel(AppLocalizations l, StrengthMetric metric) => switch (metric) {
        StrengthMetric.oneRepMax => l.metricOneRepMax,
        StrengthMetric.bestWeight => l.metricBestWeight,
        StrengthMetric.volume => l.metricVolume,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final unit = ref.watch(settingsProvider.select((s) => s.weightUnit));
    final measurements = ref.watch(measurementsProvider).dataOrNull ?? const [];
    final workouts = ref.watch(workoutsProvider).dataOrNull ?? const [];
    final exercises = ref.watch(exerciseMapProvider).dataOrNull ?? const {};

    final weightPoints = _inRange([
      for (final m in measurements)
        if (m.weightKg != null) ChartPoint(m.date, unit.fromKg(m.weightKg!)),
    ]);
    final fieldPoints = _inRange([
      for (final m in measurements)
        if (m.valueOf(_field) != null) ChartPoint(m.date, m.valueOf(_field)!),
    ]);
    final volumes = weeklyVolumes(workouts, now: DateTime.now(), weeks: 8);

    final trainedIds = <String>{for (final w in workouts) ...w.exerciseIds};
    final trained = trainedIds.where(exercises.containsKey).toList()
      ..sort((a, b) => exercises[a]!.name.compareTo(exercises[b]!.name));
    final selected = trained.contains(_exerciseId) ? _exerciseId : trained.firstOrNull;
    final strengthPoints = selected == null
        ? const <ChartPoint>[]
        : _inRange([
            for (final s in exerciseSessionStats(workouts, selected))
              ChartPoint(
                s.date,
                unit.fromKg(switch (_metric) {
                  StrengthMetric.oneRepMax => s.bestOneRepMaxKg,
                  StrengthMetric.bestWeight => s.bestWeightKg,
                  StrengthMetric.volume => s.volumeKg,
                }),
              ),
          ]);

    String weightText(double v) => '${formatNumber(v)} ${unit.symbol}';
    final fieldSuffix = _field == MeasurementField.bodyFat ? '%' : 'cm';

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final range in ChartRange.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(_rangeLabel(l, range)),
                    selected: _range == range,
                    onSelected: (_) => setState(() => _range = range),
                  ),
                ),
            ],
          ),
        ),
        _ChartCard(
          title: l.chartBodyWeight,
          empty: weightPoints.isEmpty,
          emptyText: l.chartNoWeight,
          child: SimpleLineChart(
            points: weightPoints,
            formatValue: weightText,
            formatDate: formatDateShort,
          ),
        ),
        _ChartCard(
          title: l.chartWeeklyVolume,
          empty: volumes.every((v) => v.volumeKg == 0),
          emptyText: l.chartNoWorkouts,
          child: SimpleBarChart(
            bars: [
              for (final v in volumes) BarDatum(formatDateShort(v.weekStart), unit.fromKg(v.volumeKg)),
            ],
            formatValue: (v) => '${formatNumber(v, decimals: 0)} ${unit.symbol}',
          ),
        ),
        SectionCard(
          title: l.chartStrength,
          child: trained.isEmpty
              ? Text(l.chartNoWorkouts)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownMenu<String>(
                      key: ValueKey(selected),
                      initialSelection: selected,
                      expandedInsets: EdgeInsets.zero,
                      label: Text(l.chartExercise),
                      onSelected: (value) => setState(() => _exerciseId = value),
                      dropdownMenuEntries: [
                        for (final id in trained)
                          DropdownMenuEntry(value: id, label: exercises[id]!.name),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final metric in StrengthMetric.values)
                          ChoiceChip(
                            label: Text(_metricLabel(l, metric)),
                            selected: _metric == metric,
                            onSelected: (_) => setState(() => _metric = metric),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (strengthPoints.isEmpty)
                      Text(l.chartNoDataInRange)
                    else
                      SimpleLineChart(
                        points: strengthPoints,
                        formatValue: (v) => '${formatNumber(v, decimals: 0)} ${unit.symbol}',
                        formatDate: formatDateShort,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: l.chartMeasurements,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final field in MeasurementField.values)
                    if (field != MeasurementField.weight)
                      ChoiceChip(
                        label: Text(l.measurementField(field)),
                        selected: _field == field,
                        onSelected: (_) => setState(() => _field = field),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              if (fieldPoints.isEmpty)
                Text(l.chartNoMeasurements)
              else
                SimpleLineChart(
                  points: fieldPoints,
                  formatValue: (v) => '${formatNumber(v)} $fieldSuffix',
                  formatDate: formatDateShort,
                  color: Theme.of(context).colorScheme.secondary,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.empty,
    required this.emptyText,
    required this.child,
  });

  final String title;
  final bool empty;
  final String emptyText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(title: title, child: empty ? Text(emptyText) : child);
  }
}
