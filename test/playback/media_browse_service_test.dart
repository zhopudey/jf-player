import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/audiobook_resume_service.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:moonfin/playback/headless_session_bootstrap.dart';
import 'package:moonfin/playback/last_playback_session_store.dart';
import 'package:moonfin/playback/media_browse_service.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPage = 'android.media.browse.extra.PAGE';
const _kPageSize = 'android.media.browse.extra.PAGE_SIZE';

/// Serves [totalItems] fake albums with names spread across '#' and A-Z,
/// honoring the nameStartsWith/nameLessThan/startIndex/limit windows the same
/// way the Jellyfin/Emby items APIs do.
class _FakeItemsApi implements ItemsApi {
  _FakeItemsApi({required this.totalItems, this.delay});

  final int totalItems;
  final Duration? delay;
  int listCalls = 0;

  static String nameFor(int i) {
    final bucket = i % 27;
    if (bucket == 0) return '0 Item $i';
    return '${String.fromCharCode(64 + bucket)} Item $i';
  }

  Future<Map<String, dynamic>> _page(Invocation invocation) async {
    listCalls++;
    if (delay != null) await Future<void>.delayed(delay!);
    final startsWith = invocation.namedArguments[#nameStartsWith] as String?;
    final lessThan = invocation.namedArguments[#nameLessThan] as String?;
    final start = invocation.namedArguments[#startIndex] as int? ?? 0;
    final limit = invocation.namedArguments[#limit] as int?;

    final matching = <Map<String, dynamic>>[
      for (var i = 0; i < totalItems; i++)
        if ((startsWith == null || nameFor(i).startsWith(startsWith)) &&
            (lessThan == null || nameFor(i).compareTo(lessThan) < 0))
          {'Id': 'a$i', 'Name': nameFor(i), 'Type': 'MusicAlbum'},
    ];
    final end =
        limit == null ? matching.length : (start + limit).clamp(0, matching.length).toInt();
    return {
      'Items': matching.sublist(start.clamp(0, matching.length), end),
      'TotalRecordCount': matching.length,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getItems ||
        invocation.memberName == #getAlbumArtists) {
      return _page(invocation);
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeClient implements MediaServerClient {
  _FakeClient(this._itemsApi);

  final _FakeItemsApi _itemsApi;

  @override
  ItemsApi get itemsApi => _itemsApi;

  @override
  String get baseUrl => 'http://fake';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeClientFactory implements MediaServerClientFactory {
  _FakeClientFactory(this._client);

  final MediaServerClient _client;

  @override
  Map<String, MediaServerClient> get clients => {'srv': _client};

  @override
  MediaServerClient getActiveClient() => _client;

  @override
  MediaServerClient? getClientIfExists(String serverId) =>
      serverId == 'srv' ? _client : null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeBootstrap implements HeadlessSessionBootstrap {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeResumeService implements AudiobookResumeService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeSessionStore implements LastPlaybackSessionStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

MediaBrowseService _service(_FakeItemsApi api) => MediaBrowseService(
      _FakeClientFactory(_FakeClient(api)),
      _FakeBootstrap(),
      _FakeResumeService(),
      _FakeSessionStore(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MediaBrowseService car browse', () {
    test('section node renders letter folders without any server call',
        () async {
      final api = _FakeItemsApi(totalItems: 300);
      final service = _service(api);

      final nodes = await service.getChildren('sec|albums|srv');

      expect(nodes.length, 27);
      expect(nodes.first.id, 'sec|albums|srv|az|#');
      expect(nodes.first.title, '#');
      expect(nodes.last.id, 'sec|albums|srv|az|Z');
      expect(nodes.every((n) => n.playable == false), isTrue);
      expect(api.listCalls, 0);
    });

    test('letter folder lists only matching names in a single call',
        () async {
      final api = _FakeItemsApi(totalItems: 1200);
      final service = _service(api);

      final bItems = await service.getChildren('sec|albums|srv|az|B');

      expect(bItems, isNotEmpty);
      expect(bItems.every((i) => i.title.startsWith('B')), isTrue);
      expect(api.listCalls, 1);

      final hashItems = await service.getChildren('sec|albums|srv|az|#');
      expect(hashItems, isNotEmpty);
      expect(hashItems.every((i) => i.title.startsWith('0')), isTrue);
      expect(api.listCalls, 2);
    });

    test('paged host gets exactly the requested window from the cache',
        () async {
      final api = _FakeItemsApi(totalItems: 1200);
      final service = _service(api);

      final all = await service.getChildren('sec|albums|srv|az|B');
      final callsAfterFill = api.listCalls;

      final page1 = await service.getChildren(
        'sec|albums|srv|az|B',
        {_kPage: 1, _kPageSize: 10},
      );
      expect(page1.length, 10);
      expect(page1.first.title, all[10].title);
      expect(api.listCalls, callsAfterFill);

      final pastEnd = await service.getChildren(
        'sec|albums|srv|az|B',
        {_kPage: 999, _kPageSize: 10},
      );
      expect(pastEnd, isEmpty);
      expect(api.listCalls, callsAfterFill);
    });

    test('concurrent requests for one node share a single fetch', () async {
      final api = _FakeItemsApi(
        totalItems: 300,
        delay: const Duration(milliseconds: 10),
      );
      final service = _service(api);

      final results = await Future.wait([
        service.getChildren('sec|albums|srv|az|A'),
        service.getChildren('sec|albums|srv|az|A'),
      ]);

      expect(results[0], isNotEmpty);
      expect(results[0].length, results[1].length);
      expect(api.listCalls, 1);
    });
  });
}
