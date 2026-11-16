import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Selection state for the download picker and the downloaded-media delete
/// screens.
///
/// Plain [ChangeNotifier] (not a Riverpod notifier) so the same controller
/// works from the non-Riverpod detail screen and the Riverpod-based downloads
/// screens, driven by a [ListenableBuilder] in both.
class SelectableListController extends ChangeNotifier {
  final Set<String> _selected = <String>{};
  bool _selectMode = false;

  Set<String> get selectedIds => UnmodifiableSetView(_selected);
  int get selectedCount => _selected.length;
  bool get hasSelection => _selected.isNotEmpty;
  bool get selectMode => _selectMode;

  bool isSelected(String id) => _selected.contains(id);

  /// Tri-state value for a "select all" checkbox over [ids]: true when every
  /// id is selected, false when none are, null when the selection is partial.
  bool? groupValue(Iterable<String> ids) {
    var selected = 0;
    var total = 0;
    for (final id in ids) {
      total++;
      if (_selected.contains(id)) selected++;
    }
    if (total == 0 || selected == 0) return false;
    return selected == total ? true : null;
  }

  void toggle(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void setSelected(String id, bool selected) {
    final changed = selected ? _selected.add(id) : _selected.remove(id);
    if (changed) notifyListeners();
  }

  void setAll(Iterable<String> ids, bool selected) {
    final before = _selected.length;
    if (selected) {
      _selected.addAll(ids);
    } else {
      _selected.removeAll(ids);
    }
    if (_selected.length != before) notifyListeners();
  }

  void selectAll(Iterable<String> ids) => setAll(ids, true);

  /// Replaces the whole selection — used when a filter changes and the
  /// selection has to be recomputed against the newly visible rows.
  void replaceSelection(Iterable<String> ids) {
    final next = ids.toSet();
    if (setEquals(next, _selected)) return;
    _selected
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  void enterSelectMode({String? initialId}) {
    _selectMode = true;
    if (initialId != null) _selected.add(initialId);
    notifyListeners();
  }

  void exitSelectMode() {
    _selectMode = false;
    _selected.clear();
    notifyListeners();
  }
}
