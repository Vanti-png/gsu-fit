import 'package:web/web.dart' as web;

import 'package:gsu_fit/core/web_store/json_store.dart';

/// Keeps the web build's data in the browser's localStorage. Clearing the
/// browser's site data deletes it, which is why the app suggests backups.
class LocalStoragePersistence implements KeyValuePersistence {
  web.Storage get _storage => web.window.localStorage;

  @override
  String? read(String key) => _storage.getItem(key);

  @override
  void write(String key, String value) => _storage.setItem(key, value);

  @override
  void remove(String key) => _storage.removeItem(key);
}

KeyValuePersistence createBrowserPersistence() => LocalStoragePersistence();
