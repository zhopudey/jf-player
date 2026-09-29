import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:playback_core/playback_core.dart';
import 'package:server_core/server_core.dart';

import '../data/database/offline_database.dart';
import '../data/repositories/offline_repository.dart';
import '../data/models/aggregated_item.dart';
import '../data/services/media_server_client_factory.dart';
import '../data/services/storage_path_service.dart';
import '../ui/navigation/destinations.dart';

/// Plays from the downloads list through the normal queue.
///
/// Downloaded rows become ordinary queue items; [OfflineFirstStreamResolver]
/// swaps in the local file for each one, so next/previous/auto-next behave
/// exactly as when streaming. Episodes without a finished download are
/// dropped from the queue so next never falls through to the network.
Future<void> launchOfflinePlayback(
  BuildContext context,
  DownloadedItem item, {
  List<DownloadedItem>? episodeQueue,
}) async {
  final manager = GetIt.instance<PlaybackManager>();
  final repo = GetIt.instance<OfflineRepository>();

  // The exit flow fires stop unawaited; wait so the saved position is fresh.
  await manager.pendingStop;
  final fresh = await repo.getItem(item.itemId);
  final startTicks = fresh?.playbackPositionTicks ?? item.playbackPositionTicks;
  final startPos = startTicks > 0
      ? Duration(microseconds: startTicks ~/ 10)
      : Duration.zero;

  final start = AggregatedItem.fromOffline(item);
  final downloaded = [
    for (final row in episodeQueue ?? [item])
      if (row.itemId == item.itemId ||
          (row.localFilePath != null && row.downloadStatus == 2))
        AggregatedItem.fromOffline(row),
  ];

  // Like streaming: the queue is the whole season, and the resolver decides
  // per episode whether the local file or the server serves it. If the server
  // can't be reached, fall back to just what is downloaded.
  var items = await _serverEpisodes(start) ?? downloaded;
  var startIndex = items.indexWhere((e) => e.id == start.id);
  if (startIndex < 0) {
    items = downloaded;
    startIndex = downloaded.indexWhere((e) => e.id == start.id);
  }
  startIndex = startIndex.clamp(0, items.length - 1);

  final rowsById = {for (final r in episodeQueue ?? [item]) r.itemId: r};
  for (final agg in items) {
    final row = rowsById[agg.id];
    if (row != null && (agg.isAudioLike || agg.type == 'MusicAlbum')) {
      await _injectLocalPaths(row, agg.rawData);
    }
  }

  final isAudio = start.isAudioLike ||
      start.type == 'MusicAlbum';

  await manager.playItems(items, startIndex: startIndex, startPosition: startPos);

  if (context.mounted) {
    context.push(isAudio ? Destinations.audioPlayer : Destinations.videoPlayer);
  }
}

Future<List<AggregatedItem>?> _serverEpisodes(AggregatedItem start) async {
  final seriesId = start.rawData['SeriesId'] as String?;
  if (start.type != 'Episode' || seriesId == null || seriesId.isEmpty) {
    return null;
  }
  try {
    final factory = GetIt.instance<MediaServerClientFactory>();
    final client =
        (start.serverId.isEmpty ? null : factory.getClientIfExists(start.serverId)) ??
        GetIt.instance<MediaServerClient>();
    final data = await client.itemsApi
        .getEpisodes(
          seriesId,
          seasonId: start.rawData['SeasonId'] as String?,
          fields:
              'Overview,MediaStreams,MediaSources,RunTimeTicks,Trickplay,UserData,Chapters',
        )
        .timeout(const Duration(seconds: 4));
    final list = [
      for (final raw in (data['Items'] as List? ?? const []))
        if (raw is Map<String, dynamic>)
          AggregatedItem(
            id: raw['Id'] as String? ?? '',
            serverId: start.serverId,
            rawData: raw,
          ),
    ];
    return list.length > 1 ? list : null;
  } catch (_) {
    return null;
  }
}

Future<void> _injectLocalPaths(DownloadedItem item, Map<String, dynamic> meta) async {
  if (item.posterPath != null) {
    meta['_localPosterPath'] = item.posterPath;
  }
  try {
    final storagePath = GetIt.instance<StoragePathService>();
    final imageDir = await storagePath.getImageCacheDir();
    final lyricsFile = File('${imageDir.path}/${item.itemId}/lyrics.json');
    if (await lyricsFile.exists()) {
      meta['_localLyricsPath'] = lyricsFile.path;
    }
  } catch (_) {}
}
