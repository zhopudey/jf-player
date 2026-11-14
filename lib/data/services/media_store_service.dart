import 'package:flutter/services.dart';

class MediaStoreService {
  static const _channel = MethodChannel('com.moonfin/media_store');

  /// Returns the base path for MediaStore downloads: `/storage/emulated/0/Download/Moonfin`
  static Future<String> getMediaStorePath() async {
    final path = await _channel.invokeMethod<String>('getMediaStorePath');
    return path!;
  }

  /// Creates a MediaStore entry and returns the absolute file path to write to.
  ///
  /// Only usable by writes the platform makes itself (Android's DownloadManager).
  /// A raw dart:io write to that path is discarded — use [writeFile] instead.
  static Future<String> getDownloadPath({
    required String fileName,
    String relativePath = '',
  }) async {
    final path = await _channel.invokeMethod<String>('getDownloadPath', {
      'fileName': fileName,
      'relativePath': relativePath,
    });
    return path!;
  }

  /// Writes [bytes] into `Download/Moonfin/<relativePath>/<fileName>` through the
  /// MediaStore we own the row for, returning the file's absolute path.
  static Future<String> writeFile({
    required String fileName,
    required String relativePath,
    required Uint8List bytes,
  }) async {
    final path = await _channel.invokeMethod<String>('writeFile', {
      'fileName': fileName,
      'relativePath': relativePath,
      'bytes': bytes,
    });
    return path!;
  }
}
