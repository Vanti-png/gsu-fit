import 'package:flutter/services.dart';

/// Dart side of the Kotlin code in android/app/src/main/kotlin/.
///
/// Reminders are scheduled with Android's AlarmManager and shown as plain
/// notifications by the app itself, which avoids two plugins and their
/// downloads. Schedules survive reboots (see BootReceiver).
class ReminderBridge {
  static const MethodChannel _channel = MethodChannel('gsu_fit/reminders');

  /// Asks for the notification permission (Android 13+). Returns whether
  /// notifications may be shown.
  Future<bool> requestPermission() async =>
      await _call<bool>('requestPermission') ?? false;

  Future<bool> notificationsAllowed() async =>
      await _call<bool>('notificationsAllowed') ?? false;

  /// Repeats at [hour]:[minute] on [weekdays] (1 = Monday … 7 = Sunday);
  /// an empty list means every day.
  Future<void> scheduleRepeating({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    List<int> weekdays = const [],
  }) =>
      _call<void>('scheduleRepeating', {
        'id': id,
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays,
      });

  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) =>
      _call<void>('scheduleOnce', {
        'id': id,
        'title': title,
        'body': body,
        'atMillis': at.millisecondsSinceEpoch,
      });

  Future<void> cancel(int id) => _call<void>('cancel', {'id': id});

  Future<void> cancelAll() => _call<void>('cancelAll');

  // Reminders are a convenience: a failure must never break the screen
  // that triggered them, so platform errors are swallowed here.
  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

class PickedDocument {
  const PickedDocument({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Save/open through Android's system file picker (Storage Access
/// Framework); no storage permission is needed.
class FileBridge {
  static const MethodChannel _channel = MethodChannel('gsu_fit/files');

  /// Returns false when the user cancelled the dialog.
  Future<bool> saveDocument({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final uri = await _channel.invokeMethod<String>('saveDocument', {
      'name': fileName,
      'mimeType': mimeType,
      'bytes': bytes,
    });
    return uri != null;
  }

  /// Returns null when the user cancelled the dialog.
  Future<PickedDocument?> openDocument() async {
    final result = await _channel.invokeMapMethod<String, Object?>('openDocument');
    if (result == null) return null;
    return PickedDocument(
      name: (result['name'] as String?) ?? '',
      bytes: result['bytes']! as Uint8List,
    );
  }
}
