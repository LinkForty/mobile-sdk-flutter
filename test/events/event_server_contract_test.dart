import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/attribution/attribution_context.dart';
import 'package:linkforty_flutter/errors/link_forty_error.dart';
import 'package:linkforty_flutter/events/event_queue.dart';
import 'package:linkforty_flutter/events/event_tracker.dart';
import 'package:linkforty_flutter/models/event_request.dart';
import 'package:linkforty_flutter/models/link_forty_config.dart';
import 'package:linkforty_flutter/network/http_client.dart';
import 'package:linkforty_flutter/network/http_method.dart';
import 'package:linkforty_flutter/network/http_response.dart';
import 'package:linkforty_flutter/network/network_manager.dart';
import 'package:mockito/mockito.dart';

import 'event_tracker_test.mocks.dart';

/// Answers every request with [status] and [body], or throws [error], and
/// counts the requests.
class FakeHttpClient implements HttpClient {
  int status = 200;
  String body =
      '{"eventId":"8e6c3f1e-1b2a-4c3d-9e8f-0a1b2c3d4e5f","acknowledged":true}';
  Object? error;
  final List<String> sentEventNames = [];

  @override
  Future<HttpResponse> execute({
    required String url,
    required HttpMethod method,
    Uint8List? body,
    Map<String, String>? headers,
  }) async {
    if (body != null) {
      sentEventNames.add(jsonDecode(utf8.decode(body))['eventName'] as String);
    }
    if (error != null) throw error!;
    return HttpResponse(
      statusCode: status,
      body: Uint8List.fromList(utf8.encode(this.body)),
    );
  }
}

/// The event tracker over the real [NetworkManager] and [EventQueue], answered
/// in the shapes the server sends.
void main() {
  late FakeHttpClient http;
  late MockStorageManagerProtocol storage;
  late EventQueue queue;
  late EventTracker tracker;

  setUp(() {
    http = FakeHttpClient();
    storage = MockStorageManagerProtocol();
    when(storage.getInstallId()).thenReturn('install-1');
    when(storage.loadEventQueue()).thenReturn([]);
    when(storage.saveEventQueue(any)).thenAnswer((_) async => true);
    queue = EventQueue();
    tracker = EventTracker(
      networkManager: NetworkManager(
        config: LinkFortyConfig(baseURL: Uri.parse('https://api.example.com')),
        httpClient: http,
      ),
      storageManager: storage,
      attributionContext: AttributionContext(storage: storage),
      eventQueue: queue,
    );
  });

  test('trackEvent succeeds on the server reply and queues nothing', () async {
    await tracker.trackEvent('purchase');

    expect(http.sentEventNames, ['purchase']);
    expect(queue.count, 0);
  });

  test('flushQueue sends each queued event once', () async {
    http.error = const SocketLikeException();
    for (final name in ['first', 'second']) {
      await expectLater(
        () => tracker.trackEvent(name),
        throwsA(isA<NetworkError>()),
      );
    }
    expect(queue.count, 2);

    http
      ..error = null
      ..sentEventNames.clear();
    await tracker.flushQueue();
    await tracker.flushQueue();

    expect(http.sentEventNames, ['first', 'second']);
    expect(queue.count, 0);
  });

  test('a queued event that still fails keeps its place at the head', () async {
    queue
      ..enqueue(
        EventRequest(
          installId: 'install-1',
          eventName: 'first',
          eventData: const {},
        ),
      )
      ..enqueue(
        EventRequest(
          installId: 'install-1',
          eventName: 'second',
          eventData: const {},
        ),
      );
    http.status = 503;
    http.body = '{"error":"unavailable"}';

    await tracker.flushQueue();

    expect(queue.peek().map((e) => e.eventName), ['first', 'second']);
  });

  test('an event the server rejects is not queued', () async {
    http.status = 404;
    http.body = '{"error":"Install not found"}';

    await expectLater(
      () => tracker.trackEvent('purchase'),
      throwsA(isA<InvalidResponseError>()),
    );

    expect(queue.count, 0);
  });

  test(
    'a queued event the server rejects is dropped and the rest are sent',
    () async {
      queue
        ..enqueue(
          EventRequest(
            installId: 'gone',
            eventName: 'rejected',
            eventData: const {},
          ),
        )
        ..enqueue(
          EventRequest(
            installId: 'install-1',
            eventName: 'kept',
            eventData: const {},
          ),
        );
      final client = _FirstRejected(http);

      final rejecting = EventTracker(
        networkManager: NetworkManager(
          config: LinkFortyConfig(
            baseURL: Uri.parse('https://api.example.com'),
          ),
          httpClient: client,
        ),
        storageManager: storage,
        attributionContext: AttributionContext(storage: storage),
        eventQueue: queue,
      );
      await rejecting.flushQueue();

      expect(client.sent, ['rejected', 'kept']);
      expect(queue.count, 0);
    },
  );
}

/// A connection-level failure, as the HTTP client reports when offline.
class SocketLikeException implements Exception {
  const SocketLikeException();
}

/// Rejects the first request with a 404 and accepts the rest.
class _FirstRejected implements HttpClient {
  _FirstRejected(this._inner);
  final FakeHttpClient _inner;
  final List<String> sent = [];

  @override
  Future<HttpResponse> execute({
    required String url,
    required HttpMethod method,
    Uint8List? body,
    Map<String, String>? headers,
  }) async {
    sent.add(jsonDecode(utf8.decode(body!))['eventName'] as String);
    final status = sent.length == 1 ? 404 : 200;
    return HttpResponse(
      statusCode: status,
      body: Uint8List.fromList(utf8.encode(_inner.body)),
    );
  }
}
