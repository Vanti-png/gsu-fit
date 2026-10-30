import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:gsu_fit/core/platform/native_bridge.dart';

/// Starts a browser download of [bytes] as [fileName].
Future<bool> saveDocumentInBrowser({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) async {
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}

/// Opens the browser's file chooser; null when the user cancels.
Future<PickedDocument?> openDocumentInBrowser() {
  final completer = Completer<PickedDocument?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,.csv,application/json,text/csv';

  void finish(PickedDocument? document) {
    if (!completer.isCompleted) completer.complete(document);
  }

  Future<void> read() async {
    final file = input.files?.item(0);
    if (file == null) return finish(null);
    try {
      final buffer = await file.arrayBuffer().toDart;
      finish(PickedDocument(name: file.name, bytes: buffer.toDart.asUint8List()));
    } catch (error) {
      if (!completer.isCompleted) completer.completeError(error);
    }
  }

  input.addEventListener('change', ((web.Event _) {
    read();
  }).toJS);
  input.addEventListener('cancel', ((web.Event _) {
    finish(null);
  }).toJS);
  input.click();
  return completer.future;
}
