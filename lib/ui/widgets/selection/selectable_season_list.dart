import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../l10n/app_localizations.dart';
import 'selectable_episode_list.dart';
import 'selectable_list_controller.dart';

/// One season's worth of selectable episodes.
class SelectableSeasonGroup {
  /// Season id, or a synthetic key when the season has no id of its own.
  final String id;
  final String label;
  final List<SelectableEpisodeEntry> episodes;

  const SelectableSeasonGroup({
    required this.id,
    required this.label,
    required this.episodes,
  });

  Iterable<String> get episodeIds => episodes.map((e) => e.id);
}

/// Season rows that expand into their episodes.
///
/// Selection is always tracked at *episode* granularity — a season's checkbox
/// just selects or clears every episode under it — so season-level and
/// episode-level picking share one [SelectableListController] and one
/// flattened result.
class SelectableSeasonList extends StatelessWidget {
  final List<SelectableSeasonGroup> seasons;
  final SelectableListController controller;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const SelectableSeasonList({
    super.key,
    required this.seasons,
    required this.controller,
    this.padding = EdgeInsets.zero,
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
        itemCount: seasons.length,
        itemBuilder: (context, index) {
          final season = seasons[index];
          final ids = season.episodeIds.toList();
          final groupValue = controller.groupValue(ids);
          final selectedCount =
              ids.where(controller.isSelected).length;

          return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Checkbox(
              value: groupValue,
              tristate: true,
              onChanged: (_) => controller.setAll(ids, groupValue != true),
            ),
            title: Text(
              season.label,
              style: TextStyle(
                color: AppColorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              selectedCount > 0
                  ? '${AppLocalizations.of(context).episodeCount(ids.length)} · '
                        '${AppLocalizations.of(context).itemsSelected(selectedCount)}'
                  : AppLocalizations.of(context).episodeCount(ids.length),
              style: TextStyle(
                color: AppColorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            children: [
              SelectableEpisodeList(
                entries: season.episodes,
                controller: controller,
                padding: const EdgeInsets.only(left: 24, right: 16, bottom: 8),
              ),
            ],
          );
        },
      ),
    );
  }
}
