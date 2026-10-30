import 'dart:convert';

import 'package:gsu_fit/core/web_store/json_store.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';

class WebSettingsRepository implements SettingsRepository {
  WebSettingsRepository(this._store);

  final JsonStore _store;

  static const String _settingsKey = 'app_settings';

  @override
  Future<AppSettings> load() async {
    final raw = _store.value(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppSettings.fromJson(decoded);
    } on FormatException {
      // Fall back to defaults.
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) async =>
      _store.setValue(_settingsKey, jsonEncode(settings.toJson()));

  @override
  Future<String?> getValue(String key) async => _store.value(key);

  @override
  Future<void> setValue(String key, String value) async => _store.setValue(key, value);
}
