import 'package:gsu_fit/core/web_store/json_store.dart';

/// Non-web builds use SQLite; this is only here so the conditional import
/// in providers.dart resolves.
KeyValuePersistence createBrowserPersistence() => MemoryPersistence();
