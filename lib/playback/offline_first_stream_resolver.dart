import 'package:flutter/foundation.dart';
import 'package:playback_core/playback_core.dart';

import 'offline_stream_resolver.dart';

/// Makes playback offline-first for every entry point at once.
///
/// Wraps the server's [MediaStreamResolver] and, when a completed download of
/// the requested item exists on disk, resolves to that file instead of a
/// stream URL. Because every play path funnels through
/// `PlaybackManager.playItems` -> the resolver, this one seam covers the
/// detail screen, Continue Watching, episode lists, next-episode autoplay and
/// the queue — the user never picks "play" vs "play offline".
///
/// A local copy always wins: the downloads are originals, so streaming the
/// same file over the network would only be slower.
class OfflineFirstStreamResolver implements MediaStreamResolver {
  final MediaStreamResolver _online;
  final OfflineStreamResolver _offline;

  OfflineFirstStreamResolver(this._online, this._offline);

  @override
  Future<StreamResolutionResult> resolve(
    dynamic mediaItem, {
    Map<String, dynamic>? deviceProfile,
    int? maxStreamingBitrate,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? startTimeTicks,
    String? mediaSourceId,
    bool enableDirectPlay = true,
    bool enableDirectStream = true,
    bool enableTranscoding = true,
  }) async {
    final local = await _resolveLocal(mediaItem);
    if (local != null) return local;

    return _online.resolve(
      mediaItem,
      deviceProfile: deviceProfile,
      maxStreamingBitrate: maxStreamingBitrate,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
      startTimeTicks: startTimeTicks,
      mediaSourceId: mediaSourceId,
      enableDirectPlay: enableDirectPlay,
      enableDirectStream: enableDirectStream,
      enableTranscoding: enableTranscoding,
    );
  }

  Future<StreamResolutionResult?> _resolveLocal(dynamic mediaItem) async {
    // File paths mean nothing in a browser tab, and downloads don't exist there.
    if (kIsWeb) return null;

    String itemId;
    try {
      itemId = MediaStreamResolver.extractItemId(mediaItem);
    } catch (_) {
      return null;
    }

    final result = await _offline.resolve(itemId);
    if (result == null) return null;

    return StreamResolutionResult(
      streamUrl: result.url,
      // Servers accept the item id as the media source id for single-source
      // items; SyncService already reports offline progress the same way.
      mediaSourceId: result.itemId,
      playMethod: StreamPlayMethod.directPlay,
      container: _containerOf(result.url),
      mediaType: MediaStreamResolver.detectMediaType(
        result.mediaStreams,
        fallbackUrl: result.url,
      ),
      normalizationGainDb: MediaStreamResolver.extractNormalizationGainDb(
        result.mediaStreams,
      ),
      mediaStreams: result.mediaStreams,
      externalSubtitles: [
        for (final sub in result.externalSubtitles)
          ExternalSubtitle(
            // Local sidecar path; the manager passes it through untouched
            // because a file path carries no api_key query to merge.
            deliveryUrl: sub.path,
            title: sub.title,
            language: sub.language,
            codec: sub.codec ?? 'srt',
            streamIndex: sub.index,
          ),
      ],
    );
  }

  String? _containerOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    return path.substring(dot + 1).toLowerCase();
  }
}
