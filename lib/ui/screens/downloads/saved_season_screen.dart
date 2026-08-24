import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/database/offline_database.dart';
import '../../../data/models/aggregated_item.dart';
import '../../../data/providers/offline_providers.dart';
import '../../../data/services/download_service.dart';
import '../../../util/platform_detection.dart';
import '../../../l10n/app_localizations.dart';
import '../../../playback/offline_playback_launcher.dart';
import '../../widgets/offline_image.dart';
import '../../widgets/overlay_sheet.dart';
import '../../widgets/adaptive/adaptive_dialog.dart';
import '../../widgets/focus/request_initial_focus.dart';
import '../../widgets/selection/selectable_episode_list.dart';
import '../../widgets/selection/selectable_list_controller.dart';
import '../../widgets/selection/selection_bars.dart';

class SavedSeasonScreen extends ConsumerStatefulWidget {
  final String seasonId;

  const SavedSeasonScreen({
    super.key,
    required this.seasonId,
  });

  @override
  ConsumerState<SavedSeasonScreen> createState() => _SavedSeasonScreenState();
}

class _SavedSeasonScreenState extends ConsumerState<SavedSeasonScreen> {
  final _controller = SelectableListController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSelectionChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSelectionChanged() => setState(() {});

  @override
  Widget build(BuildContext context) =>
      RequestInitialFocus(child: _buildContent(context, ref));

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final seasonAsync = ref.watch(downloadedItemProvider(widget.seasonId));
    final episodesAsync = ref.watch(
      downloadedSeasonEpisodesProvider(widget.seasonId),
    );
    final episodes = episodesAsync.valueOrNull ?? const <DownloadedItem>[];

    final seasonName =
        seasonAsync.valueOrNull?.name ?? AppLocalizations.of(context).season;

    return Scaffold(
      backgroundColor: AppColorScheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, seasonName, episodes.isNotEmpty),
            if (_controller.selectMode && episodes.isNotEmpty)
              SelectionToolbar(
                controller: _controller,
                allIds: episodes.map((e) => e.itemId).toList(),
              ),
            Expanded(
              child: episodesAsync.when(
                data: (episodes) => _buildEpisodeList(context, episodes),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Text(
                    AppLocalizations.of(context).errorLoadingEpisodes,
                    style: TextStyle(color: AppColorScheme.statusRequested),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _controller.selectMode
          ? SelectionActionBar(
              controller: _controller,
              icon: Icons.delete,
              label: AppLocalizations.of(context).deleteSelected,
              destructive: true,
              onConfirm: () => _deleteSelected(context, episodes),
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context, String title, bool hasEpisodes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
      child: Row(
        children: [
          if (!PlatformDetection.isTV)
            IconButton(
              icon: Icon(Icons.arrow_back, color: AppColorScheme.onSurface),
              onPressed: () => context.pop(),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (hasEpisodes)
            IconButton(
              icon: Icon(
                _controller.selectMode ? Icons.close : Icons.checklist,
                color: AppColorScheme.onSurface,
              ),
              onPressed: () => _controller.selectMode
                  ? _controller.exitSelectMode()
                  : _controller.enterSelectMode(),
            ),
        ],
      ),
    );
  }

  Widget _buildEpisodeList(BuildContext context, List<DownloadedItem> episodes) {
    if (episodes.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).noDownloadedEpisodes,
          style: TextStyle(color: AppColorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }

    if (_controller.selectMode) {
      return SelectableEpisodeList(
        controller: _controller,
        scrollable: true,
        entries: [
          for (final episode in episodes) _entry(context, episode),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: episodes.length,
      itemBuilder: (context, index) => _EpisodeRow(
        episode: episodes[index],
        onTap: () => launchOfflinePlayback(context, episodes[index], episodeQueue: episodes),
        // Long-press starts a selection with this episode ticked, Findroid
        // style, instead of the old single-item delete confirm.
        onLongPress: () =>
            _controller.enterSelectMode(initialId: episodes[index].itemId),
      ),
    );
  }

  SelectableEpisodeEntry _entry(BuildContext context, DownloadedItem episode) {
    final l10n = AppLocalizations.of(context);
    final metadata = _parseMetadata(episode.metadataJson);
    final runtime = metadata['RunTimeTicks'] as int?;
    final durationMin = runtime != null ? (runtime / 600000000).round() : null;
    final season = episode.parentIndexNumber;
    final number = episode.indexNumber;

    return SelectableEpisodeEntry(
      id: episode.itemId,
      label: number == null
          ? ''
          : (season != null
                ? l10n.seasonEpisodeLabel(season, number)
                : l10n.episodeNumber(number)),
      title: episode.name,
      subtitle: durationMin != null ? l10n.durationMinutes(durationMin) : null,
      progress: episode.playbackPositionTicks > 0 && runtime != null && runtime > 0
          ? episode.playbackPositionTicks / runtime
          : null,
      thumbnailBuilder: (context) => OfflineImage(
        localPath: episode.thumbPath ?? episode.posterPath,
        width: 112,
        height: 63,
      ),
    );
  }

  Future<void> _deleteSelected(
    BuildContext context,
    List<DownloadedItem> episodes,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selected = episodes
        .where((e) => _controller.isSelected(e.itemId))
        .toList();
    if (selected.isEmpty) return;

    final confirmed = await showFocusRestoringDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text(l10n.deleteSelected),
        content: Text(l10n.deleteSelectedCount(selected.length)),
        actions: [
          adaptiveDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          adaptiveDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            isDestructive: true,
            child: Text(
              l10n.delete,
              style: TextStyle(color: AppColorScheme.statusRequested),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final downloadService = GetIt.instance<DownloadService>();
    await downloadService.deleteDownloadedItems(
      selected.map(AggregatedItem.fromOffline).toList(),
    );
    _controller.exitSelectMode();
  }

  Map<String, dynamic> _parseMetadata(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

class _EpisodeRow extends StatelessWidget {
  final DownloadedItem episode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _EpisodeRow({
    required this.episode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = _parseMetadata(episode.metadataJson);
    final runtime = metadata['RunTimeTicks'] as int?;
    final durationMin = runtime != null ? (runtime / 600000000).round() : null;
    final overview = metadata['Overview'] as String? ?? '';
    final progress = episode.playbackPositionTicks > 0 && runtime != null && runtime > 0
        ? episode.playbackPositionTicks / runtime
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadius.circular(6),
              child: SizedBox(
                width: 160,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OfflineImage(
                      localPath: episode.thumbPath ?? episode.posterPath,
                      width: 160,
                      height: 90,
                    ),
                    if (progress != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor:
                              AppColorScheme.onSurface.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(AppColorScheme.accent),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _episodeLabel(context),
                    style: TextStyle(
                      color: AppColorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    episode.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (durationMin != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).durationMinutes(durationMin),
                      style: TextStyle(
                        color: AppColorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (overview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _episodeLabel(BuildContext context) {
    final s = episode.parentIndexNumber;
    final e = episode.indexNumber;
    if (s != null && e != null) return AppLocalizations.of(context).seasonEpisodeLabel(s, e);
    if (e != null) return AppLocalizations.of(context).episodeNumber(e);
    return '';
  }

  Map<String, dynamic> _parseMetadata(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
