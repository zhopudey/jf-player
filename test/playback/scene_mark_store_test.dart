import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/scene_marks/scene_mark.dart';
import 'package:moonfin/playback/scene_marks/scene_mark_store.dart';

SceneMark _m(String id, int ms, SceneMarkType t) => SceneMark(
  id: id,
  sceneId: 's1',
  itemId: 'item1',
  title: 'Film',
  year: 2001,
  positionMs: ms,
  type: t,
  createdAt: DateTime.utc(2026, 11, 20),
);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('marks'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('marks survive reopening the store', () async {
    final f = File('${dir.path}/scene_marks.json');
    final a = await SceneMarkStore.open(f);
    await a.add(_m('1', 3810000, SceneMarkType.start));
    await a.add(_m('2', 4090000, SceneMarkType.end));
    final b = await SceneMarkStore.open(f);
    expect(b.all.map((m) => m.positionMs), [3810000, 4090000]);
    expect(b.all.first.itemId, 'item1');
  });

  test('corrupt main file falls back to backup', () async {
    final f = File('${dir.path}/scene_marks.json');
    final a = await SceneMarkStore.open(f);
    await a.add(_m('1', 1000, SceneMarkType.point));
    await a.add(_m('2', 2000, SceneMarkType.song));
    f.writeAsStringSync('{ truncated');
    final b = await SceneMarkStore.open(f);
    expect(b.all.length, greaterThanOrEqualTo(1));
  });

  test('update changes type and persists', () async {
    final f = File('${dir.path}/scene_marks.json');
    final a = await SceneMarkStore.open(f);
    await a.add(_m('1', 1000, SceneMarkType.start));
    await a.update('1', type: SceneMarkType.point, note: 'x');
    final b = await SceneMarkStore.open(f);
    expect(b.all.single.type, SceneMarkType.point);
    expect(b.all.single.note, 'x');
  });
}
