import 'package:gsu_fit/features/cardio/domain/cardio_session.dart';

/// Energy estimates from MET values (Compendium of Physical Activities):
/// kcal = MET × body weight (kg) × hours.
class CalorieCalculator {
  const CalorieCalculator._();

  /// Moderate-to-vigorous resistance training.
  static const double strengthMet = 5.0;

  static double met(CardioType type, {double? speedKmh}) {
    switch (type) {
      case CardioType.running:
        if (speedKmh == null) return 9.8;
        if (speedKmh < 8) return 6.0;
        if (speedKmh < 9.7) return 8.3;
        if (speedKmh < 10.8) return 9.8;
        if (speedKmh < 12.1) return 10.5;
        if (speedKmh < 13.8) return 11.5;
        if (speedKmh < 16.1) return 12.8;
        return 14.5;
      case CardioType.walking:
        if (speedKmh == null) return 3.5;
        if (speedKmh < 3.2) return 2.0;
        if (speedKmh < 4.0) return 2.8;
        if (speedKmh < 5.6) return 3.5;
        if (speedKmh < 6.4) return 4.3;
        if (speedKmh < 7.2) return 5.0;
        return 7.0;
      case CardioType.cycling:
        if (speedKmh == null) return 7.5;
        if (speedKmh < 16) return 4.0;
        if (speedKmh < 19.3) return 6.8;
        if (speedKmh < 22.5) return 8.0;
        if (speedKmh < 25.7) return 10.0;
        if (speedKmh < 30.6) return 12.0;
        return 15.8;
      case CardioType.swimming:
        return 6.0;
      case CardioType.rowing:
        return 7.0;
      case CardioType.elliptical:
        return 5.0;
      case CardioType.jumpRope:
        return 11.8;
      case CardioType.hiking:
        return 6.0;
      case CardioType.other:
        return 5.0;
    }
  }

  static double estimate({
    required CardioType type,
    required Duration duration,
    required double weightKg,
    double? distanceKm,
  }) {
    final hours = duration.inSeconds / 3600;
    if (hours <= 0 || weightKg <= 0) return 0;
    final speed = (distanceKm != null && distanceKm > 0) ? distanceKm / hours : null;
    return met(type, speedKmh: speed) * weightKg * hours;
  }

  static double strength({required Duration duration, required double weightKg}) {
    if (weightKg <= 0) return 0;
    return strengthMet * weightKg * duration.inSeconds / 3600;
  }

  /// Time per kilometre, e.g. 5:30 min/km.
  static Duration? pacePerKm(Duration duration, double? distanceKm) {
    if (distanceKm == null || distanceKm <= 0) return null;
    return Duration(seconds: (duration.inSeconds / distanceKm).round());
  }
}
