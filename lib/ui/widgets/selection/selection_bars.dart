import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../l10n/app_localizations.dart';
import 'selectable_list_controller.dart';

/// Header row for a selectable list: tri-state "select all" over [allIds],
/// an optional filter chip, and the running selected count.
class SelectionToolbar extends StatelessWidget {
  final SelectableListController controller;
  final List<String> allIds;

  /// Optional filter chip (the download picker's "Unwatched" toggle).
  final String? filterLabel;
  final bool filterSelected;
  final ValueChanged<bool>? onFilterChanged;

  const SelectionToolbar({
    super.key,
    required this.controller,
    required this.allIds,
    this.filterLabel,
    this.filterSelected = false,
    this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final groupValue = controller.groupValue(allIds);
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          child: Row(
            children: [
              Checkbox(
                value: groupValue,
                tristate: true,
                onChanged: (_) => controller.setAll(allIds, groupValue != true),
              ),
              Flexible(
                child: Text(
                  l10n.selectAll,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColorScheme.onSurface),
                ),
              ),
              const Spacer(),
              if (filterLabel != null && onFilterChanged != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: Text(filterLabel!),
                    selected: filterSelected,
                    onSelected: onFilterChanged,
                  ),
                ),
              Text(
                l10n.itemsSelected(controller.selectedCount),
                style: TextStyle(
                  color: AppColorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom confirm bar — disabled until something is selected.
class SelectionActionBar extends StatelessWidget {
  final SelectableListController controller;
  final String label;
  final IconData icon;
  final VoidCallback onConfirm;
  final bool destructive;

  const SelectionActionBar({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.onConfirm,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final enabled = controller.hasSelection;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(icon),
                label: Text(label),
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: AppColorScheme.statusRequested,
                      )
                    : null,
                onPressed: enabled ? onConfirm : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
