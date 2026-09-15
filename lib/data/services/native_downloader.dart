import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Progress snapshot for a download owned by Android's DownloadManager.
class NativeDownloadStatus {
  final String status;
  final int bytesSoFar;
  final int totalBytes;
  final int reason;

  const NativeDownloadStatus({
    required this.status,
    required this.bytesSoFar,
    required this.totalBytes,
    required this.reason,
  });

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';

  /// The DownloadManager row disappeared — treated as a failure, since the
  /// only ways it happens are removal or a system clear-out.
  bool get isGone => status == 'gone';

  bool get isTerminal => isDone || isFailed || isGone;
}

/// Thin wrapper over Android's DownloadManager.
///
/// dart:io's HttpClient is the bottleneck for large media downloads — measured
/// at ~8 MB/s per connection with a CPU core pegged, against ~45 MB/s for the
/// platform downloader on identical hardware, network and server. See
/// [NativeDownloader] on the Kotlin side.
class NativeDownloader {
  const NativeDownloader._();

  static const MethodChannel _channel = MethodChannel(
    'com.moonfin/native_downloader',
  );

  /// Android only — every other platform keeps the dart:io path.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Queues a download and returns the DownloadManager id.
  static Future<int> enqueue({
    required String url,
    required String savePath,
    Map<String, String> headers = const <String, String>{},
    String? title,
    bool allowMetered = false,
  }) async {
    final id = await _channel.invokeMethod<int>('enqueue', <String, Object?>{
      'url': url,
      'savePath': savePath,
      'headers': headers,
      'title': title,
      'allowMetered': allowMetered,
    });
    if (id == null) {
      throw StateError('DownloadManager returned no download id');
    }
    return id;
  }

  static Future<NativeDownloadStatus> status(int id) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'status',
      <String, Object?>{'id': id},
    );
    if (raw == null) {
      return const NativeDownloadStatus(
        status: 'gone',
        bytesSoFar: 0,
        totalBytes: -1,
        reason: 0,
      );
    }
    return NativeDownloadStatus(
      status: raw['status'] as String? ?? 'gone',
      bytesSoFar: (raw['bytesSoFar'] as num?)?.toInt() ?? 0,
      totalBytes: (raw['totalBytes'] as num?)?.toInt() ?? -1,
      reason: (raw['reason'] as num?)?.toInt() ?? 0,
    );
  }

  /// Stops the transfer and deletes the partial file.
  static Future<void> cancel(int id) async {
    try {
      await _channel.invokeMethod<bool>('cancel', <String, Object?>{'id': id});
    } catch (_) {
      // A download that already finished or vanished is not worth surfacing.
    }
  }
}
