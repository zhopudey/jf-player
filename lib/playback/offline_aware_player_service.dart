import 'package:flutter/foundation.dart';
import 'package:playback_core/playback_core.dart';

import '../data/repositories/offline_repository.dart';

/// Keeps progress for locally-played files correct whether or not the server
/// can be reached.
///
/// When [OfflineFirstStreamResolver] hands the player a downloaded file, the
/// normal server reporting still runs — so watching a downloaded episode at
/// home updates Jellyfin live. When the server is unreachable the report fails
/// and the position stays in the offline DB marked unsynced, which is exactly
/// what `SyncService` pushes on the next reconnect.
class OfflineAwarePlayerService implements PlayerService {
  final PlayerService _inner;
  final OfflineRepository _offlineRepo;

  OfflineAwarePlayerService(this._inner, this._offlineRepo);

  /// A resolution whose stream is a local file rather than a server URL.
  bool _isLocal(StreamResolutionResult resolution) {
    final url = resolution.streamUrl;
    return !url.startsWith('http://') && !url.startsWith('https://');
  }

  String? _itemId(dynamic mediaItem) {
    try {
      return MediaStreamResolver.extractItemId(mediaItem);
    } catch (_) {
      return null;
    }
  }

  /// Writes the position locally (unsynced), then tries the server. A
  /// successful report re-writes it as synced so the reconnect sync doesn't
  /// push it again; a failure leaves it queued.
  Future<void> _recordLocalProgress(
    String itemId,
    Duration position,
    Future<void> Function() report,
  ) async {
    final ticks = position.inMicroseconds * 10;
    try {
      await _offlineRepo.updatePlaybackPosition(itemId, ticks);
    } catch (e) {
      debugPrint('[OfflinePlayback] local progress write failed: $e');
    }

    try {
      await report();
      await _offlineRepo.setSyncedPlaybackPosition(itemId, ticks);
    } catch (_) {
      // Server unreachable — the unsynced row above is the queue.
    }
  }

  @override
  Future<void> onPlaybackStart(
    dynamic mediaItem,
    StreamResolutionResult resolution, {
    int? positionTicks,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    Future<void> report() => _inner.onPlaybackStart(
      mediaItem,
      resolution,
      positionTicks: positionTicks,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
    );

    if (!_isLocal(resolution)) return report();

    // Offline playback must not fail because the server can't be told about it.
    try {
      await report();
    } catch (_) {}
  }

  @override
  Future<void> onPlaybackProgress(
    dynamic mediaItem,
    StreamResolutionResult resolution,
    Duration position, {
    bool isPaused = false,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    Future<void> report() => _inner.onPlaybackProgress(
      mediaItem,
      resolution,
      position,
      isPaused: isPaused,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
    );

    final itemId = _isLocal(resolution) ? _itemId(mediaItem) : null;
    if (itemId == null) return report();

    await _recordLocalProgress(itemId, position, report);
  }

  @override
  Future<void> onPlaybackStop(
    dynamic mediaItem,
    StreamResolutionResult resolution,
    Duration position,
  ) async {
    Future<void> report() =>
        _inner.onPlaybackStop(mediaItem, resolution, position);

    final itemId = _isLocal(resolution) ? _itemId(mediaItem) : null;
    if (itemId == null) return report();

    await _recordLocalProgress(itemId, position, report);
  }

  @override
  Future<void> closeLiveStream(String liveStreamId) =>
      _inner.closeLiveStream(liveStreamId);

  @override
  void dispose() => _inner.dispose();
}
