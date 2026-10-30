/// All weights are stored in kilograms; [WeightUnit] only affects display
/// and input.
enum WeightUnit { kg, lb }

const double kgPerLb = 0.45359237;

extension WeightUnitX on WeightUnit {
  String get symbol => this == WeightUnit.kg ? 'kg' : 'lb';

  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg / kgPerLb;

  double toKg(double value) => this == WeightUnit.kg ? value : value * kgPerLb;

  /// Smallest common plate jump in this unit, expressed in kg.
  double get plateStepKg => this == WeightUnit.kg ? 2.5 : 5 * kgPerLb;
}

double roundToStep(double value, double step) {
  if (step <= 0) return value;
  return (value / step).round() * step;
}

/// Trims floating point noise such as 62.50000000001.
double cleanDouble(double value, {int decimals = 2}) =>
    double.parse(value.toStringAsFixed(decimals));
