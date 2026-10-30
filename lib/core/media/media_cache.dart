import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum MediaFailure { offline, notFound, server, invalidUrl }

class MediaException implements Exception {
  const MediaException(this.failure, [this.statusCode]);

  final MediaFailure failure;
  final int? statusCode;

  @override
  String toString() => 'MediaException($failure, $statusCode)';
}

/// Minimal download-once cache for exercise images and videos.
///
/// Files are stored under the app's cache directory keyed by a hash of the
/// URL, so a picture or clip costs data only the first time it is shown.
/// Android may clear the cache when storage runs low; the next view simply
/// downloads it again.
class MediaCache {
  MediaCache(this._directory);

  final Directory _directory;
  final Map<String, Future<File>> _inFlight = {};

  static Future<MediaCache> create() async {
    final base = await getTemporaryDirectory();
    final directory = Directory(p.join(base.path, 'media_cache'));
    await directory.create(recursive: true);
    return MediaCache(directory);
  }

  File _fileFor(String url) {
    final uriPath = Uri.tryParse(url)?.path ?? '';
    var extension = p.extension(uriPath).toLowerCase();
    if (extension.length > 5) extension = '';
    return File(p.join(_directory.path, '${_hash(url)}$extension'));
  }

  /// Returns the cached file, or null when it has not been downloaded yet.
  Future<File?> cached(String url) async {
    final file = _fileFor(url);
    return await file.exists() ? file : null;
  }

  /// Returns the cached file, downloading it first if necessary.
  /// [onProgress] receives a 0..1 fraction, or null when the size is unknown.
  Future<File> get(String url, {void Function(double? progress)? onProgress}) {
    final existing = _inFlight[url];
    if (existing != null) return existing;
    final future = _download(url, onProgress);
    _inFlight[url] = future;
    future.whenComplete(() {
      _inFlight.remove(url);
    }).ignore();
    return future;
  }

  Future<File> _download(String url, void Function(double?)? onProgress) async {
    final target = _fileFor(url);
    if (await target.exists()) return target;

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const MediaException(MediaFailure.invalidUrl);
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    final partial = File('${target.path}.part');
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        throw MediaException(MediaFailure.notFound, response.statusCode);
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw MediaException(MediaFailure.server, response.statusCode);
      }
      final total = response.contentLength;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(total > 0 ? received / total : null);
        }
      } finally {
        await sink.close();
      }
      return await partial.rename(target.path);
    } on SocketException {
      throw const MediaException(MediaFailure.offline);
    } on HandshakeException {
      throw const MediaException(MediaFailure.offline);
    } on HttpException {
      throw const MediaException(MediaFailure.offline);
    } on TimeoutException {
      throw const MediaException(MediaFailure.offline);
    } finally {
      client.close(force: true);
      if (await partial.exists()) {
        await partial.delete();
      }
    }
  }

  Future<int> sizeInBytes() async {
    var total = 0;
    if (!await _directory.exists()) return 0;
    await for (final entity in _directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clear() async {
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
    await _directory.create(recursive: true);
  }

  /// Two independent 32-bit FNV-1a hashes give a 64-bit, filename-safe key.
  static String _hash(String input) {
    final bytes = utf8.encode(input);
    var a = 0x811c9dc5;
    var b = 0x01000193 ^ bytes.length;
    for (final byte in bytes) {
      a = ((a ^ byte) * 0x01000193) & 0xffffffff;
      b = ((b ^ (byte + 31)) * 0x01000193) & 0xffffffff;
    }
    return a.toRadixString(16).padLeft(8, '0') + b.toRadixString(16).padLeft(8, '0');
  }
}
