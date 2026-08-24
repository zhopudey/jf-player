import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import 'selectable_list_controller.dart';

/// Presentation data for one selectable episode row.
///
/// Deliberately server/offline agnostic: the online download picker builds
/// these from [AggregatedItem]s with network thumbnails, the downloads screens
/// build them from Drift `DownloadedItem` rows with local thumbnails, and both
/// get the same row.
class SelectableEpisodeEntry {
  /// Item id — the identity the [SelectableListController] tracks.
  final String id;

  /// Small label above the title, e.g. `S1:E4`. Empty hides the line.
  final String label;
  final String title;

  /// Secondary line — runtime, size, whatever the caller has.
  final String? subtitle;

  final bool isPlayed;

  /// Already present on disk. Excluded from the picker's default selection and
  /// badged, but still selectable (re-download).
  final bool alreadyDownloaded;

  /// Watch progress 0..1, drawn as a bar over the thumbnail.
  final double? progress;

  final WidgetBuilder? thumbnailBuilder;

  const SelectableEpisodeEntry({
    required this.id,
    required this.title,
    this.label = '',
    this.subtitle,
    this.isPlayed = false,
    this.alreadyDownloaded = false,
    this.progress,
    this.thumbnailBuilder,
  });
}

/// Checkbox-per-row episode list.
///
/// Shrink-wrapped and non-scrolling by default so it can sit inside an
/// [ExpansionTile] or a parent scroll view; pass [scrollable] for a
/// standalone list.
class SelectableEpisodeList extends StatelessWidget {
  final List<SelectableEpisodeEntry> entries;
  final SelectableListController controller;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const SelectableEpisodeList({
    super.key,
    required this.entries,
    required this.controller,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView.builder(
        padding: padding,
        shrinkWrap: !scrollable,
        physics: scrollable ? null : const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return SelectableEpisodeRow(
            entry: entry,
            selected: controller.isSelected(entry.id),
            onChanged: () => controller.toggle(entry.id),
          );
        },
      ),
    );
  }
}

class SelectableEpisodeRow extends StatelessWidget {
  final SelectableEpisodeEntry entry;
  final bool selected;
  final VoidCallback onChanged;

  const SelectableEpisodeRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = AppColorScheme.onSurface;

    return InkWell(
      onTap: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onChanged(),
            ),
            ClipRRect(
              borderRadius: AppRadius.circular(6),
              child: SizedBox(
                width: 112,
                height: 63,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    entry.thumbnailBuilder?.call(context) ??
                        Container(
                          color: onSurface.withValues(alpha: 0.05),
                          child: Icon(
                            Icons.movie_outlined,
                            color: onSurface.withValues(alpha: 0.24),
                          ),
                        ),
                    if (entry.progress != null && entry.progress! > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: entry.progress!.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: onSurface.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(
                            AppColorScheme.accent,
                          ),
                        ),
                      ),
                    if (entry.isPlayed)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColorScheme.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.label.isNotEmpty)
                    Text(
                      entry.label,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (entry.subtitle != null)
                    Text(
                      entry.subtitle!,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (entry.alreadyDownloaded)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.download_done,
                  size: 18,
                  color: AppColorScheme.statusAvailable,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
