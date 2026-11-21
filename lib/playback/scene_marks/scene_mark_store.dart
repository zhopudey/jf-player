import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scene_mark.dart';

/// Durable queue of [SceneMark]s. Every change is written to disk before the
/// call returns (temp file + rename), so killing the app never loses a mark.
/// Marks are never deleted, only flagged `synced` after a successful POST.
class SceneMarkStore extends ChangeNotifier {
  SceneMarkStore._(this._file, this._dio);

  static const _syncUrlKey = 'scene_marks_sync_url';

  final File _file;
  final Dio _dio;
  final List<SceneMark> _marks = [];
  Future<void> _writeChain = Future.value();
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _syncing = false;
  String? lastSyncError;

  static SceneMarkStore? _instance;

  /// App-wide instance (documents dir).
  static Future<SceneMarkStore> instance() async {
    final existing = _instance;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final store = await open(File('${dir.path}/scene_marks.json'));
    store._startAutoSync();
    return _instance = store;
  }

  @visibleForTesting
  static Future<SceneMarkStore> open(File file, {Dio? dio}) async {
    final store = SceneMarkStore._(file, dio ?? Dio());
    await store._load();
    return store;
  }

  List<SceneMark> get all => List.unmodifiable(_marks);
  List<SceneMark> forItem(String itemId) =>
      _marks.where((m) => m.itemId == itemId).toList();
  int get pendingCount => _marks.where((m) => !m.synced).length;

  Future<void> _load() async {
    final backup = File('${_file.path}.bak');
    for (final f in [_file, backup]) {
      try {
        if (!await f.exists()) continue;
        final list = jsonDecode(await f.readAsString()) as List;
        _marks
          ..clear()
          ..addAll(list.map((e) => SceneMark.fromJson(e as Map<String, dynamic>)));
        return;
      } catch (_) {
        // try the next copy
      }
    }
  }

  Future<void> _persist() {
    final json = jsonEncode(_marks.map((m) => m.toJson()).toList());
    _writeChain = _writeChain.then((_) async {
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      if (await _file.exists()) {
        await _file.copy('${_file.path}.bak');
      }
      await tmp.rename(_file.path);
    });
    return _writeChain;
  }

  Future<void> add(SceneMark mark) async {
    _marks.add(mark);
    notifyListeners();
    await _persist();
    unawaited(sync());
  }

  /// Change a mark's note or type (e.g. a lone start becomes a point).
  Future<void> update(String id, {String? note, SceneMarkType? type}) async {
    final i = _marks.indexWhere((m) => m.id == id);
    if (i < 0) return;
    if (note != null) _marks[i].note = note.isEmpty ? null : note;
    if (type != null) _marks[i].type = type;
    _marks[i].synced = false;
    notifyListeners();
    await _persist();
    unawaited(sync());
  }

  /// Removes a mark. Only used by the explicit "undo" on a just-made mark.
  Future<void> remove(String id) async {
    _marks.removeWhere((m) => m.id == id);
    notifyListeners();
    await _persist();
  }

  // ---- sync target (single URL, empty by default) ----

  Future<String> getSyncUrl() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_syncUrlKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setSyncUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_syncUrlKey, url.trim());
    unawaited(sync());
  }

  void _startAutoSync() {
    _connSub = Connectivity().onConnectivityChanged.listen((r) {
      if (!r.contains(ConnectivityResult.none)) unawaited(sync());
    });
  }

  /// POSTs unsynced marks as a JSON array. No-op while the URL is empty.
  Future<void> sync() async {
    if (_syncing) return;
    final url = await getSyncUrl();
    if (url.isEmpty) return;
    final pending = _marks.where((m) => !m.synced).toList();
    if (pending.isEmpty) return;
    _syncing = true;
    try {
      final res = await _dio.post<dynamic>(
        url,
        data: pending.map((m) => m.toJson()..remove('synced')).toList(),
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      if ((res.statusCode ?? 500) >= 200 && (res.statusCode ?? 500) < 300) {
        for (final m in pending) {
          m.synced = true;
        }
        lastSyncError = null;
        notifyListeners();
        await _persist();
      } else {
        lastSyncError = 'HTTP ${res.statusCode}';
      }
    } catch (e) {
      lastSyncError = e is DioException ? (e.type.name) : 'failed';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// All marks as the marks.json payload (array of the spec'd objects).
  String exportJson() => const JsonEncoder.withIndent('  ').convert(
    _marks.map((m) => m.toJson()..remove('synced')).toList(),
  );

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}
