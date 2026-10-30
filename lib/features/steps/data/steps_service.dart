import 'package:health/health.dart';

enum StepsStatus { ok, needsPermission, notInstalled, needsUpdate, unavailable, error }

class StepsResult {
  const StepsResult(this.status, {this.steps = 0});

  final StepsStatus status;
  final int steps;
}

/// Reads today's step count from Android Health Connect. Health Connect
/// aggregates the phone's own counter and wearables, so the app needs no
/// background service. Permission is only requested when the user turns
/// the feature on.
class StepsService {
  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> _types = [HealthDataType.STEPS];
  static const List<HealthDataAccess> _access = [HealthDataAccess.READ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<StepsStatus> _availability() async {
    // if/else instead of a switch so new enum values in later plugin
    // versions do not break the build.
    final status = await _health.getHealthConnectSdkStatus();
    if (status == HealthConnectSdkStatus.sdkAvailable) return StepsStatus.ok;
    if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
      return StepsStatus.needsUpdate;
    }
    if (status == HealthConnectSdkStatus.sdkUnavailable) return StepsStatus.notInstalled;
    return StepsStatus.unavailable;
  }

  Future<StepsResult> todaySteps() async {
    try {
      await _configure();
      final availability = await _availability();
      if (availability != StepsStatus.ok) return StepsResult(availability);
      final granted = await _health.hasPermissions(_types, permissions: _access) ?? false;
      if (!granted) return const StepsResult(StepsStatus.needsPermission);
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return StepsResult(StepsStatus.ok, steps: steps ?? 0);
    } catch (_) {
      return const StepsResult(StepsStatus.error);
    }
  }

  /// Shows Health Connect's permission screen. Returns true when granted.
  Future<bool> requestPermission() async {
    try {
      await _configure();
      return await _health.requestAuthorization(_types, permissions: _access);
    } catch (_) {
      return false;
    }
  }

  /// Opens the Play Store page of Health Connect.
  Future<void> installHealthConnect() async {
    try {
      await _configure();
      await _health.installHealthConnect();
    } catch (_) {
      // Nothing else to do: the card keeps showing the install hint.
    }
  }
}
