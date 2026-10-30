import 'dart:typed_data';

import 'package:gsu_fit/core/platform/native_bridge.dart';

// Only the web build uses these (see web_files_web.dart); Android goes
// through the Kotlin method channel.

Future<bool> saveDocumentInBrowser({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) =>
    throw UnsupportedError('Browser downloads are only available on the web');

Future<PickedDocument?> openDocumentInBrowser() =>
    throw UnsupportedError('Browser file picking is only available on the web');
