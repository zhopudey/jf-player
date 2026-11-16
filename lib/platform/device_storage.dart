import 'package:flutter/services.dart';

import '../util/download_utils.dart';
import '../util/platform_detection.dart';

/// Real free space on the device, as opposed to the app's own optional
/// storage-limit setting.
class DeviceStorage {
  static const _channel = MethodChannel('org.moonfin.androidtv/platform');

  /// Kept free on top of every download so the device never fills to zero.
  static const reserveBytes = 2 * 1024 * 1024 * 1024;

  /// Bytes available at [path], or null where unknown (non-Android, or the
  /// platform call failed). Callers treat null as "don't block".
  static Future<int?> freeBytes(String path) async {
    if (!PlatformDetection.isAndroid) return null;
    try {
      final v = await _channel.invokeMethod<int>('freeSpaceBytes', {'path': path});
      return v;
    } catch (_) {
      return null;
    }
  }

  /// True when [neededBytes] fits in [freeBytes] after the reserve.
  /// Unknown free space (null) or unknown size (<= 0) never blocks.
  static bool fits(int neededBytes, int? freeBytes) {
    if (freeBytes == null || neededBytes <= 0) return true;
    return neededBytes <= freeBytes - reserveBytes;
  }

  /// One short line for the user, e.g. "Needs 12.4 GB, 8.1 GB free".
  static String shortfall(int neededBytes, int freeBytes) =>
      'Needs ${formatBytes(neededBytes)}, ${formatBytes(freeBytes)} free';
}
