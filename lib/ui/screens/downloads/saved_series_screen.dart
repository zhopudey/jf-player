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
import '../../navigation/destinations.dart';
import '../../widgets/offline_image.dart';
import '../../widgets/overlay_sheet.dart';
import '../../widgets/adaptive/adaptive_dialog.dart';
import '../../widgets/focus/request_initial_focus.dart';
import '../../widgets/selection/selectable_episode_list.dart';
import '../../widgets/selection/selectable_list_controller.dart';
import '../../widgets/selection/selectable_season_list.dart';
import '../../widgets/selection/selection_bars.dart';

class SavedSeriesScreen extends ConsumerStatefulWidget {
  final String seriesId;

  const SavedSeriesScreen({super.key, required this.seriesId});

  @override
  ConsumerState<SavedSeriesScreen> createState() => _SavedSeriesScreenState();
}

class _SavedSeriesScreenState extends ConsumerState<SavedSeriesScreen> {
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
      RequestInitialFocus(child: _buildScreen(context, ref));

  Widget _buildScreen(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(downloadedItemProvider(widget.seriesId));
    final episodesAsync = ref.watch(downloadedEpisodesProvider(widget.seriesId));
    final episodes = episodesAsync.valueOrNull ?? const <DownloadedItem>[];

    return Scaffold(
      backgroundColor: AppColorScheme.background,
      body: SafeArea(
        child: seriesAsync.when(
          data: (series) {
            if (series == null) {
              return Center(
                child: Text(
                  AppLocalizations.of(context).seriesNotFound,
                  style: TextStyle(
                    color: AppColorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              );
            }
            return _buildContent(context, ref, series, episodesAsync);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Text(
              AppLocalizations.of(context).errorLoadingSeries,
              style: TextStyle(color: AppColorScheme.statusRequested),
            ),
          ),
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

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DownloadedItem series,
    AsyncValue<List<DownloadedItem>> episodesAsync,
  ) {
    final metadata = _parseMetadata(series.metadataJson);
    final overview = metadata['Overview'] as String? ?? '';
    final year = metadata['ProductionYear']?.toString() ?? '';
    final rating = metadata['OfficialRating'] as String? ?? '';
    final episodes = episodesAsync.valueOrNull ?? const <DownloadedItem>[];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(
            context,
            series,
            overview,
            year,
            rating,
            episodes.isNotEmpty,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              AppLocalizations.of(context).downloadedEpisodes,
              style: TextStyle(
                color: AppColorScheme.onSurface.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (_controller.selectMode && episodes.isNotEmpty)
          SliverToBoxAdapter(
            child: SelectionToolbar(
              controller: _controller,
              allIds: episodes.map((e) => e.itemId).toList(),
            ),
          ),
        episodesAsync.when(
          data: (episodes) => _controller.selectMode
              ? SliverToBoxAdapter(
                  child: SelectableSeasonList(
                    seasons: _seasonGroups(context, episodes),
                    controller: _controller,
                  ),
                )
              : _buildSeasonList(context, ref, episodes),
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SliverToBoxAdapter(
            child: Center(
              child: Text(
                AppLocalizations.of(context).errorLoadingSeries,
                style: TextStyle(color: AppColorScheme.statusRequested),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DownloadedItem series,
    String overview,
    String year,
    String rating,
    bool hasEpisodes,
  ) {
    return Stack(
      children: [
        if (series.backdropPath != null)
          SizedBox(
            height: 220,
            width: double.infinity,
            child: ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColorScheme.scrim.withValues(alpha: 0.3),
                  AppColorScheme.scrim,
                ],
              ).createShader(rect),
              blendMode: BlendMode.darken,
              child: OfflineImage(
                localPath: series.backdropPath,
                width: double.infinity,
                height: 220,
              ),
            ),
          ),
        if (!PlatformDetection.isTV)
            Positioned(
            top: series.backdropPath != null ? 140 : 16,
            left: 20,
            child: IconButton(
                icon: Icon(Icons.arrow_back, color: AppColorScheme.onSurface),
              onPressed: () => context.pop(),
              style: IconButton.styleFrom(
                backgroundColor: AppColorScheme.scrim.withValues(alpha: 0.45),
              ),
            ),
          ),
        if (hasEpisodes)
          Positioned(
            top: series.backdropPath != null ? 140 : 16,
            right: 20,
            child: IconButton(
              icon: Icon(
                _controller.selectMode ? Icons.close : Icons.checklist,
                color: AppColorScheme.onSurface,
              ),
              onPressed: () => _controller.selectMode
                  ? _controller.exitSelectMode()
                  : _controller.enterSelectMode(),
              style: IconButton.styleFrom(
                backgroundColor: AppColorScheme.scrim.withValues(alpha: 0.45),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: series.backdropPath != null ? 180 : 60, left: 20, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (series.logoPath != null)
                OfflineImage(localPath: series.logoPath, height: 60)
              else
                Text(
                  series.name,
                  style: TextStyle(
                    color: AppColorScheme.onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (year.isNotEmpty) _chip(year),
                  if (rating.isNotEmpty) _chip(rating),
                ],
              ),
              if (overview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  overview,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: AppRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 12,
        ),
      ),
    );
  }

  /// Downloaded episodes grouped into seasons, in season/episode order.
  Map<int?, List<DownloadedItem>> _groupBySeason(List<DownloadedItem> episodes) {
    final seasons = <int?, List<DownloadedItem>>{};
    for (final ep in episodes) {
      (seasons[ep.parentIndexNumber] ??= []).add(ep);
    }
    return seasons;
  }

  List<int?> _sortedSeasonKeys(Map<int?, List<DownloadedItem>> seasons) =>
      seasons.keys.toList()..sort((a, b) => (a ?? 0).compareTo(b ?? 0));

  String _seasonLabel(BuildContext context, int? seasonNumber) =>
      seasonNumber != null
      ? AppLocalizations.of(context).seasonNumber(seasonNumber)
      : AppLocalizations.of(context).specials;

  List<SelectableSeasonGroup> _seasonGroups(
    BuildContext context,
    List<DownloadedItem> episodes,
  ) {
    final seasons = _groupBySeason(episodes);
    final l10n = AppLocalizations.of(context);
    return [
      for (final key in _sortedSeasonKeys(seasons))
        SelectableSeasonGroup(
          id: seasons[key]!.first.seasonId ?? 'season-${key ?? 0}',
          label: _seasonLabel(context, key),
          episodes: [
            for (final ep in seasons[key]!)
              SelectableEpisodeEntry(
                id: ep.itemId,
                label: ep.indexNumber != null
                    ? l10n.episodeNumber(ep.indexNumber!)
                    : '',
                title: ep.name,
                thumbnailBuilder: (context) => OfflineImage(
                  localPath: ep.thumbPath ?? ep.posterPath,
                  width: 112,
                  height: 63,
                ),
              ),
          ],
        ),
    ];
  }

  SliverList _buildSeasonList(BuildContext context, WidgetRef ref, List<DownloadedItem> episodes) {
    final seasons = _groupBySeason(episodes);
    final sortedKeys = _sortedSeasonKeys(seasons);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final seasonNum = sortedKeys[index];
          final seasonEpisodes = seasons[seasonNum]!;
          final seasonId = seasonEpisodes.first.seasonId;
          final seasonLabel = _seasonLabel(context, seasonNum);

          return _SeasonSection(
            label: seasonLabel,
            episodeCount: seasonEpisodes.length,
            onTap: seasonId != null
                ? () => context.push(Destinations.downloadedSeason(widget.seriesId, seasonId))
                : null,
            // Long-press starts a selection with this season ticked instead of
            // the old single-season delete confirm.
            onLongPress: () {
              _controller.enterSelectMode();
              _controller.setAll(
                seasonEpisodes.map((e) => e.itemId),
                true,
              );
            },
          );
        },
        childCount: sortedKeys.length,
      ),
    );
  }

  Map<String, dynamic> _parseMetadata(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Deletes through [DownloadService] rather than touching files and the DB
  /// here, so the picker and this screen share one deletion path (which also
  /// prunes the now-empty season/series rows and their images).
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
}

class _SeasonSection extends StatelessWidget {
  final String label;
  final int episodeCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _SeasonSection({
    required this.label,
    required this.episodeCount,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        label,
        style: TextStyle(
          color: AppColorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        AppLocalizations.of(context).episodeCount(episodeCount),
        style: TextStyle(
          color: AppColorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColorScheme.onSurface.withValues(alpha: 0.38),
      ),
    );
  }
}
