import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:server_core/server_core.dart';

import '../../../data/models/aggregated_item.dart';
import '../../../data/repositories/offline_repository.dart';
import '../../../data/services/storage_path_service.dart';
import '../../../platform/device_storage.dart';
import '../../../util/download_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/selection/selectable_episode_list.dart';
import '../../widgets/selection/selectable_list_controller.dart';
import '../../widgets/selection/selectable_season_list.dart';
import '../../widgets/selection/selection_bars.dart';

/// Lets the user pick exactly which episodes of a season or series to
/// download, instead of the old all-or-nothing behaviour.
///
/// Pops a `List<AggregatedItem>` (the chosen episodes) or null on cancel; the
/// caller runs the quality picker and hands the list to
/// `DownloadService.downloadItems`. Nothing here touches the download engine.
class DownloadPickerScreen extends StatefulWidget {
  final String title;
  final ImageApi imageApi;

  /// Episodes to choose from. Loaded here (not by the caller) so the screen
  /// can show its own spinner while a series' episodes are fetched.
  final Future<List<AggregatedItem>> Function() loadEpisodes;

  /// Group rows into expandable seasons — series-level picking.
  final bool groupBySeason;

  /// Series the episodes belong to, used to badge what is already on disk.
  final String? seriesId;

  const DownloadPickerScreen({
    super.key,
    required this.title,
    required this.imageApi,
    required this.loadEpisodes,
    this.groupBySeason = false,
    this.seriesId,
  });

  @override
  State<DownloadPickerScreen> createState() => _DownloadPickerScreenState();
}

class _DownloadPickerScreenState extends State<DownloadPickerScreen> {
  final _controller = SelectableListController();

  List<AggregatedItem> _episodes = const [];
  Set<String> _downloadedIds = const {};
  bool _loading = true;
  bool _unwatchedOnly = false;

  /// Real free space where downloads go; null when unknown (never blocks).
  int? _freeBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final episodes = await widget.loadEpisodes();

    var downloadedIds = const <String>{};
    final seriesId = widget.seriesId;
    if (seriesId != null && GetIt.instance.isRegistered<OfflineRepository>()) {
      final rows = await GetIt.instance<OfflineRepository>().getSeriesEpisodes(
        seriesId,
      );
      downloadedIds = rows
          .where((row) => row.downloadStatus == 2)
          .map((row) => row.itemId)
          .toSet();
    }

    int? freeBytes;
    if (GetIt.instance.isRegistered<StoragePathService>()) {
      final root = await GetIt.instance<StoragePathService>().getOfflineRoot();
      freeBytes = await DeviceStorage.freeBytes(root.path);
    }

    if (!mounted) return;
    setState(() {
      _freeBytes = freeBytes;
      _episodes = episodes;
      _downloadedIds = downloadedIds;
      _loading = false;
    });
    _applyDefaultSelection();
  }

  /// Everything visible that isn't already on disk — so the old
  /// "download the whole season" flow stays one confirm away.
  void _applyDefaultSelection() {
    _controller.replaceSelection(
      _visibleEpisodes
          .where((ep) => !_downloadedIds.contains(ep.id))
          .map((ep) => ep.id),
    );
  }

  List<AggregatedItem> get _visibleEpisodes => _unwatchedOnly
      ? _episodes.where((ep) => !ep.isPlayed).toList()
      : _episodes;

  void _onUnwatchedChanged(bool value) {
    setState(() => _unwatchedOnly = value);
    // Selection must never contain hidden rows, so recompute it against what
    // is visible now rather than keeping stale ids around.
    _applyDefaultSelection();
  }

  SelectableEpisodeEntry _entry(BuildContext context, AggregatedItem ep) {
    final l10n = AppLocalizations.of(context);
    final season = ep.parentIndexNumber;
    final number = ep.indexNumber;
    final label = number == null
        ? ''
        : (season != null
              ? l10n.seasonEpisodeLabel(season, number)
              : l10n.episodeNumber(number));
    final runtime = ep.runtime;
    final tag = ep.primaryImageTag;

    return SelectableEpisodeEntry(
      id: ep.id,
      label: label,
      title: ep.name,
      subtitle: runtime != null ? l10n.durationMinutes(runtime.inMinutes) : null,
      isPlayed: ep.isPlayed,
      alreadyDownloaded: _downloadedIds.contains(ep.id),
      progress: (ep.playedPercentage ?? 0) > 0
          ? ep.playedPercentage! / 100
          : null,
      thumbnailBuilder: tag == null
          ? null
          : (context) => CachedNetworkImage(
              imageUrl: widget.imageApi.getPrimaryImageUrl(
                ep.id,
                maxHeight: 160,
                tag: tag,
              ),
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
    );
  }

  List<SelectableSeasonGroup> _seasonGroups(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grouped = <int?, List<AggregatedItem>>{};
    for (final ep in _visibleEpisodes) {
      (grouped[ep.parentIndexNumber] ??= []).add(ep);
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) => (a ?? 0).compareTo(b ?? 0));

    return [
      for (final key in keys)
        SelectableSeasonGroup(
          id: grouped[key]!.first.seasonId ?? 'season-${key ?? 0}',
          label: key != null ? l10n.seasonNumber(key) : l10n.specials,
          episodes: [
            for (final ep in grouped[key]!) _entry(context, ep),
          ],
        ),
    ];
  }

  void _confirm() {
    final selected = _controller.selectedIds;
    Navigator.pop(
      context,
      _episodes.where((ep) => selected.contains(ep.id)).toList(),
    );
  }

  /// Original-file size of the current selection. Transcoded downloads are
  /// smaller, so this is the upper bound the quality sheet refines.
  int get _selectedBytes {
    final selected = _controller.selectedIds;
    var total = 0;
    for (final ep in _episodes) {
      if (selected.contains(ep.id)) total += sourceSizeBytes(ep);
    }
    return total;
  }

  /// "≈ 31.2 GB selected · 58.0 GB free", turning into a warning when the
  /// selection (as originals) will not fit, so episodes can be unticked here.
  Widget _spaceStrip() {
    final free = _freeBytes;
    final needed = _selectedBytes;
    if (free == null && needed <= 0) return const SizedBox.shrink();
    final fits = DeviceStorage.fits(needed, free);
    final parts = <String>[
      if (needed > 0) '≈ ${formatBytes(needed)} selected',
      if (free != null) '${formatBytes(free)} free',
    ];
    final text = fits
        ? parts.join(' · ')
        : 'Space low for full selection — untick some episodes '
              '(${parts.join(' · ')})';
    return Container(
      width: double.infinity,
      color: fits ? Colors.transparent : const Color(0x33FF9800),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: fits
              ? AppColorScheme.onSurface.withValues(alpha: 0.6)
              : const Color(0xFFFFB74D),
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = _visibleEpisodes;

    return Scaffold(
      backgroundColor: AppColorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _episodes.isEmpty
          ? Center(
              child: Text(
                l10n.noEpisodesLoaded,
                style: TextStyle(
                  color: AppColorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          : Column(
              children: [
                SelectionToolbar(
                  controller: _controller,
                  allIds: visible.map((ep) => ep.id).toList(),
                  filterLabel: l10n.unwatched,
                  filterSelected: _unwatchedOnly,
                  onFilterChanged: _onUnwatchedChanged,
                ),
                const Divider(height: 1),
                Expanded(
                  child: widget.groupBySeason
                      ? SelectableSeasonList(
                          seasons: _seasonGroups(context),
                          controller: _controller,
                          scrollable: true,
                        )
                      : SelectableEpisodeList(
                          entries: [
                            for (final ep in visible) _entry(context, ep),
                          ],
                          controller: _controller,
                          scrollable: true,
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _loading || _episodes.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => _spaceStrip(),
                ),
                SelectionActionBar(
                  controller: _controller,
                  icon: Icons.download,
                  label: l10n.download,
                  onConfirm: _confirm,
                ),
              ],
            ),
    );
  }
}
