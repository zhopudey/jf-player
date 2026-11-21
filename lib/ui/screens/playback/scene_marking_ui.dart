import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../playback/scene_marks/scene_mark.dart';
import '../../../playback/scene_marks/scene_mark_store.dart';

/// 63:30 -> "1:03:30", 75 s -> "1:15".
String formatMarkTime(int ms) {
  final s = ms ~/ 1000;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

const _rangeColor = Color(0xFFFFC107);
const _songColor = Color(0xFFFF4081);

/// Editor-style markers drawn over the seek bar track.
/// Slider track spans the width minus the 14 px overlay radius on each side.
class SceneMarkTimelinePainter extends CustomPainter {
  SceneMarkTimelinePainter({
    required this.marks,
    required this.durationMs,
    required this.pendingStartMs,
    required this.positionMs,
  });

  final List<SceneMark> marks;
  final double durationMs;
  final int? pendingStartMs;
  final double positionMs;

  static const _inset = 14.0;

  double _x(double ms, double w) =>
      _inset + (ms / durationMs).clamp(0.0, 1.0) * (w - 2 * _inset);

  @override
  void paint(Canvas canvas, Size size) {
    if (durationMs <= 1) return;
    final cy = size.height / 2;
    final range = Paint()..color = _rangeColor.withValues(alpha: 0.85);

    // Completed scenes: pair start/end by sceneId.
    final starts = {
      for (final m in marks.where((m) => m.type == SceneMarkType.start))
        m.sceneId: m,
    };
    for (final end in marks.where((m) => m.type == SceneMarkType.end)) {
      final s = starts[end.sceneId];
      if (s == null) continue;
      final a = _x(s.positionMs.toDouble(), size.width);
      final b = _x(end.positionMs.toDouble(), size.width);
      canvas.drawRRect(
        RRect.fromLTRBR(a, cy - 5, b < a + 3 ? a + 3 : b, cy + 5,
            const Radius.circular(2)),
        range,
      );
    }
    // Pending start: translucent range up to the playhead.
    if (pendingStartMs != null) {
      final a = _x(pendingStartMs!.toDouble(), size.width);
      final b = _x(positionMs, size.width);
      if (b > a) {
        canvas.drawRect(
          Rect.fromLTRB(a, cy - 5, b, cy + 5),
          Paint()..color = _rangeColor.withValues(alpha: 0.35),
        );
      }
    }
    // Edge ticks for starts/ends, full ticks for point/song.
    for (final m in marks) {
      final x = _x(m.positionMs.toDouble(), size.width);
      final isSong = m.type == SceneMarkType.song;
      final isEdge =
          m.type == SceneMarkType.start || m.type == SceneMarkType.end;
      final h = isEdge ? 11.0 : 9.0;
      final paint = Paint()
        ..strokeWidth = isEdge ? 3 : 2.5
        ..color = isSong
            ? _songColor
            : (isEdge ? _rangeColor : Colors.white);
      canvas.drawLine(Offset(x, cy - h - 4), Offset(x, cy + h + 4), paint);
      if (!isEdge) {
        canvas.drawCircle(Offset(x, cy - h - 6), 3.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SceneMarkTimelinePainter old) =>
      old.marks.length != marks.length ||
      old.durationMs != durationMs ||
      old.pendingStartMs != pendingStartMs ||
      old.positionMs != positionMs ||
      !identical(old.marks, marks);
}

/// The big tap target shown while marking mode is on.
class SceneMarkBar extends StatelessWidget {
  const SceneMarkBar({
    super.key,
    required this.expectingEnd,
    required this.onTap,
    required this.onLongPress,
    required this.onOpenSheet,
    required this.onExit,
    required this.pendingSync,
  });

  final bool expectingEnd;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOpenSheet;
  final VoidCallback onExit;
  final int pendingSync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Marks',
            onPressed: onOpenSheet,
            icon: Badge(
              isLabelVisible: pendingSync > 0,
              label: Text('$pendingSync'),
              child: const Icon(Icons.list_alt_rounded, color: Colors.white),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onLongPress: onLongPress,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: expectingEnd ? Colors.redAccent : _rangeColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(190, 52),
              ),
              icon: Icon(expectingEnd ? Icons.stop_rounded : Icons.flag_rounded),
              label: Text(
                expectingEnd ? 'MARK END' : 'MARK START',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Leave marking mode',
            onPressed: onExit,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

Future<void> showSceneNoteDialog(
  BuildContext context,
  SceneMarkStore store,
  SceneMark mark,
) async {
  final controller = TextEditingController(text: mark.note ?? '');
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Note for ${formatMarkTime(mark.positionMs)}'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 140,
        decoration: const InputDecoration(hintText: 'One line (optional)'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (text != null) await store.update(mark.id, note: text.trim());
}

/// Marks of this film + export + sync URL.
Future<void> showSceneMarksSheet(
  BuildContext context,
  SceneMarkStore store,
  String itemId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _MarksSheet(store: store, itemId: itemId),
  );
}

class _MarksSheet extends StatefulWidget {
  const _MarksSheet({required this.store, required this.itemId});
  final SceneMarkStore store;
  final String itemId;

  @override
  State<_MarksSheet> createState() => _MarksSheetState();
}

class _MarksSheetState extends State<_MarksSheet> {
  String _status = '';
  bool _busy = false;

  void _say(String s) {
    if (mounted) setState(() => _status = s);
  }

  Future<void> _export() async {
    final store = widget.store;
    setState(() => _busy = true);
    _say('Exporting ${store.all.length} marks…');
    try {
      final bytes = utf8.encode(store.exportJson());
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save marks.json',
        fileName: 'marks.json',
        bytes: bytes,
      );
      _say(path == null ? 'Export cancelled' : 'Saved ${store.all.length} marks');
    } catch (e) {
      _say('Export failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setUrl() async {
    final c = TextEditingController(text: await widget.store.getSyncUrl());
    if (!mounted) return;
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync URL'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'empty = no sync (export only)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (url == null) return;
    await widget.store.setSyncUrl(url);
    _say(url.trim().isEmpty ? 'Sync off' : 'Sync URL saved');
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    _say('Syncing…');
    final url = await widget.store.getSyncUrl();
    if (url.isEmpty) {
      _say('No sync URL set');
    } else {
      await widget.store.sync();
      _say(widget.store.lastSyncError == null
          ? 'Synced'
          : 'Sync failed (${widget.store.lastSyncError}) — marks kept');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final marks = widget.store.forItem(widget.itemId)
          ..sort((a, b) => a.positionMs.compareTo(b.positionMs));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${marks.length} marks in this film · ${widget.store.all.length} total · ${widget.store.pendingCount} unsynced',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in marks)
                        ListTile(
                          dense: true,
                          leading: Icon(switch (m.type) {
                            SceneMarkType.start => Icons.flag_rounded,
                            SceneMarkType.end => Icons.stop_rounded,
                            SceneMarkType.song => Icons.music_note_rounded,
                            SceneMarkType.point => Icons.place_rounded,
                          }),
                          title: Text(
                            '${m.type.name} · ${formatMarkTime(m.positionMs)}',
                          ),
                          subtitle: m.note == null ? null : Text(m.note!),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_note_rounded),
                            onPressed: () =>
                                showSceneNoteDialog(context, widget.store, m),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _export,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Export marks'),
                    ),
                    OutlinedButton(onPressed: _busy ? null : _syncNow, child: const Text('Sync now')),
                    OutlinedButton(onPressed: _setUrl, child: const Text('Sync URL')),
                  ],
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_status),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
