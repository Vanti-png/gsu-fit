import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/features/workout/domain/workout.dart';

/// Live "mm:ss" since [since].
class ElapsedClock extends StatefulWidget {
  const ElapsedClock({super.key, required this.since, this.style});

  final DateTime since;
  final TextStyle? style;

  @override
  State<ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<ElapsedClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(formatClock(DateTime.now().difference(widget.since)), style: widget.style);
  }
}

/// Countdown shown at the bottom of the workout screen. The end time is
/// absolute, so the countdown stays correct after the app was in the
/// background.
class RestTimerBar extends StatefulWidget {
  const RestTimerBar({
    super.key,
    required this.endsAt,
    required this.totalSeconds,
    required this.onAdjust,
    required this.onSkip,
    required this.onFinished,
  });

  final DateTime endsAt;
  final int totalSeconds;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;
  final VoidCallback onFinished;

  @override
  State<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends State<RestTimerBar> {
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant RestTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) _fired = false;
  }

  void _tick() {
    if (!mounted) return;
    final remaining = widget.endsAt.difference(DateTime.now());
    if (remaining <= Duration.zero && !_fired) {
      _fired = true;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      widget.onFinished();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final remaining = widget.endsAt.difference(DateTime.now());
    final fraction = widget.totalSeconds <= 0
        ? 0.0
        : (remaining.inMilliseconds / (widget.totalSeconds * 1000)).clamp(0.0, 1.0).toDouble();
    return Material(
      color: scheme.tertiaryContainer,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 44,
                child: CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 5,
                  color: scheme.onTertiaryContainer,
                  backgroundColor: scheme.onTertiaryContainer.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.restTitle, style: TextStyle(color: scheme.onTertiaryContainer)),
                      Text(
                        formatClock(remaining),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l.restMinus15,
                onPressed: () => widget.onAdjust(-15),
                icon: const Icon(Icons.remove_circle_outline),
                color: scheme.onTertiaryContainer,
              ),
              IconButton(
                tooltip: l.restPlus15,
                onPressed: () => widget.onAdjust(15),
                icon: const Icon(Icons.add_circle_outline),
                color: scheme.onTertiaryContainer,
              ),
              TextButton(onPressed: widget.onSkip, child: Text(l.restSkip)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One editable set: weight, reps (or seconds) and a done button.
class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.number,
    required this.unit,
    required this.timed,
    required this.onChanged,
    required this.onToggle,
  });

  final WorkoutSet set;
  final int number;
  final WeightUnit unit;
  final bool timed;
  final ValueChanged<WorkoutSet> onChanged;
  final VoidCallback onToggle;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController _weight = TextEditingController(text: _weightText());
  late final TextEditingController _reps = TextEditingController(text: '${widget.set.reps}');

  String _weightText() =>
      widget.set.weightKg == 0 ? '' : formatInputNumber(widget.unit.fromKg(widget.set.weightKg));

  @override
  void didUpdateWidget(covariant SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only overwrite the text when the value changed from outside (e.g. a
    // unit switch), never while the user is typing the same value.
    final typedWeight = parseDecimal(_weight.text);
    final typedKg = typedWeight == null ? 0.0 : widget.unit.toKg(typedWeight);
    if ((typedKg - widget.set.weightKg).abs() > 0.01 || oldWidget.unit != widget.unit) {
      _weight.text = _weightText();
    }
    if ((parseInt(_reps.text) ?? 0) != widget.set.reps) {
      _reps.text = '${widget.set.reps}';
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _emit() {
    final weight = parseDecimal(_weight.text);
    widget.onChanged(widget.set.copyWith(
      weightKg: weight == null ? 0 : cleanDouble(widget.unit.toKg(weight)),
      reps: parseInt(_reps.text) ?? 0,
    ));
  }

  InputDecoration _decoration(String label) => InputDecoration(
        isDense: true,
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final done = widget.set.completed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: done ? scheme.primaryContainer.withValues(alpha: 0.6) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${widget.number}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _weight,
              decoration: _decoration(widget.unit.symbol),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              onChanged: (_) => _emit(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _reps,
              decoration: _decoration(widget.timed ? l.unitSecondsShort : l.workoutReps),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => _emit(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: done ? l.workoutSetUndo : l.workoutSetDone,
            iconSize: 32,
            isSelected: done,
            onPressed: () {
              FocusScope.of(context).unfocus();
              widget.onToggle();
            },
            icon: const Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}
