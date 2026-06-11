import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:linkforty_flutter/attribution/attribution_context.dart';
import 'package:linkforty_flutter/events/event_tracker.dart';
import 'package:linkforty_flutter/events/event_queue.dart';
import 'package:linkforty_flutter/network/network_manager.dart';
import 'package:linkforty_flutter/storage/storage_manager.dart';
import 'package:linkforty_flutter/models/event_request.dart';
import 'package:linkforty_flutter/models/event_response.dart';
import 'package:linkforty_flutter/network/http_method.dart';
import 'package:linkforty_flutter/errors/link_forty_error.dart';

import 'event_tracker_test.mocks.dart';

@GenerateMocks([NetworkManagerProtocol, StorageManagerProtocol, EventQueue])
void main() {
  late MockNetworkManagerProtocol mockNetworkManager;
  late MockStorageManagerProtocol mockStorageManager;
  late MockEventQueue mockQueue;
  late EventTracker eventTracker;
  late AttributionContext attributionContext;

  setUp(() {
    mockNetworkManager = MockNetworkManagerProtocol();
    mockStorageManager = MockStorageManagerProtocol();
    mockQueue = MockEventQueue();

    // Setup default storage behavior
    when(mockStorageManager.loadEventQueue()).thenReturn([]);
    when(mockStorageManager.saveEventQueue(any)).thenAnswer((_) async => true);

    // Setup default queue behavior
    when(mockQueue.count).thenReturn(0);
    when(mockQueue.isEmpty).thenReturn(true);
    when(mockQueue.enqueue(any)).thenReturn(true);
    when(mockQueue.peek()).thenReturn([]);

    attributionContext = AttributionContext(storage: mockStorageManager);

    eventTracker = EventTracker(
      networkManager: mockNetworkManager,
      storageManager: mockStorageManager,
      attributionContext: attributionContext,
      eventQueue: mockQueue,
    );
  });

  group('EventTracker', () {
    test('trackEvent throws if name is empty', () async {
      await expectLater(
        () => eventTracker.trackEvent(''),
        throwsA(isA<InvalidEventDataError>()),
      );
    });

    test('trackEvent throws if not initialized (no install ID)', () async {
      when(mockStorageManager.getInstallId()).thenReturn(null);

      await expectLater(
        () => eventTracker.trackEvent('test'),
        throwsA(isA<NotInitializedError>()),
      );
    });

    test('trackEvent sends event immediately if successful', () async {
      when(mockStorageManager.getInstallId()).thenReturn('inst_1');
      when(
        mockNetworkManager.request<EventResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => const EventResponse(success: true));

      await eventTracker.trackEvent('test', {'key': 'value'});

      verify(
        mockNetworkManager.request<EventResponse>(
          endpoint: '/api/sdk/v1/event',
          method: HttpMethod.post,
          body: argThat(
            isA<EventRequest>()
                .having((e) => e.eventName, 'eventName', 'test')
                .having((e) => e.installId, 'installId', 'inst_1'),
            named: 'body',
          ),
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);

      // Should try to flush queue after success
      verify(mockQueue.isEmpty).called(1); // Called in flushQueue
    });

    test('trackEvent stamps the active last-click attribution', () async {
      when(mockStorageManager.getInstallId()).thenReturn('inst_1');
      when(mockStorageManager.saveAttribution(any))
          .thenAnswer((_) async => true);
      when(
        mockNetworkManager.request<EventResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => const EventResponse(success: true));

      // A deep link opens the app, then the user does something.
      await attributionContext.recordDeepLinkOpen(
        linkId: 'link-A',
        clickId: 'click-1',
      );
      await eventTracker.trackEvent('purchase');

      verify(
        mockNetworkManager.request<EventResponse>(
          endpoint: '/api/sdk/v1/event',
          method: HttpMethod.post,
          body: argThat(
            isA<EventRequest>()
                .having((e) => e.attributedLinkId, 'attributedLinkId', 'link-A')
                .having(
                  (e) => e.attributedClickId,
                  'attributedClickId',
                  'click-1',
                )
                .having((e) => e.sessionId, 'sessionId', isNotNull),
            named: 'body',
          ),
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);
    });

    test('trackScreenView emits a screen_view with screen/previousScreen',
        () async {
      when(mockStorageManager.getInstallId()).thenReturn('inst_1');
      when(
        mockNetworkManager.request<EventResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => const EventResponse(success: true));

      await eventTracker.trackScreenView('Home');
      await eventTracker.trackScreenView('ProductDetail');

      verify(
        mockNetworkManager.request<EventResponse>(
          endpoint: '/api/sdk/v1/event',
          method: HttpMethod.post,
          body: argThat(
            isA<EventRequest>()
                .having((e) => e.eventName, 'eventName', 'screen_view')
                .having((e) => e.eventData['screen'], 'screen', 'ProductDetail')
                .having(
                  (e) => e.eventData['previousScreen'],
                  'previousScreen',
                  'Home',
                ),
            named: 'body',
          ),
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);
    });

    test('trackScreenView throws on an empty name', () async {
      await expectLater(
        () => eventTracker.trackScreenView('  '),
        throwsA(isA<InvalidEventDataError>()),
      );
    });

    test('trackEvent queues event if network fails', () async {
      when(mockStorageManager.getInstallId()).thenReturn('inst_1');
      when(
        mockNetworkManager.request<EventResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(NetworkError(Exception('fail')));

      // Expect it to rethrow after queuing
      await expectLater(
        () => eventTracker.trackEvent('test'),
        throwsA(isA<NetworkError>()),
      );

      verify(
        mockQueue.enqueue(
          argThat(
            isA<EventRequest>().having((e) => e.eventName, 'eventName', 'test'),
          ),
        ),
      ).called(1);
    });

    test('trackRevenue validates amount', () async {
      await expectLater(
        () => eventTracker.trackRevenue(amount: -1, currency: 'USD'),
        throwsA(isA<InvalidEventDataError>()),
      );
    });

    test('trackRevenue delegates to trackEvent', () async {
      when(mockStorageManager.getInstallId()).thenReturn('inst_1');
      when(
        mockNetworkManager.request<EventResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => const EventResponse(success: true));

      await eventTracker.trackRevenue(amount: 10.0, currency: 'USD');

      verify(
        mockNetworkManager.request<EventResponse>(
          endpoint: '/api/sdk/v1/event',
          method: HttpMethod.post,
          body: argThat(
            isA<EventRequest>()
                .having((e) => e.eventName, 'eventName', 'revenue')
                .having(
                  (e) => e.eventData['revenue'],
                  'revenue property',
                  10.0,
                ),
            named: 'body',
          ),
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);
    });

    test('flushQueue sends queued events relative order', () async {
      final event1 = EventRequest(
        installId: '1',
        eventName: 'e1',
        eventData: {},
      );
      final event2 = EventRequest(
        installId: '1',
        eventName: 'e2',
        eventData: {},
      );

      // Simulate queue with 2 items
      final responses = [false, false, true];
      when(
        mockQueue.isEmpty,
      ).thenAnswer((_) => responses.removeAt(0)); // loop control
      final events = [event1, event2];
      when(
        mockQueue.dequeue(),
      ).thenAnswer((_) => events.isNotEmpty ? events.removeAt(0) : null);

      when(
        mockNetworkManager.request<EventResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => const EventResponse(success: true));

      await eventTracker.flushQueue();

      verify(
        mockNetworkManager.request(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: event1,
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);

      verify(
        mockNetworkManager.request(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: event2,
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);
    });

    test('flushQueue stops and requeues on error', () async {
      final event1 = EventRequest(
        installId: '1',
        eventName: 'e1',
        eventData: {},
      );

      when(mockQueue.isEmpty).thenReturn(false);
      when(mockQueue.dequeue()).thenReturn(event1);

      when(
        mockNetworkManager.request<EventResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(NetworkError(Exception('fail')));

      await eventTracker.flushQueue();

      // Should requeue
      verify(mockQueue.enqueue(event1)).called(1);
    });

    test(
      'trackEvent persists queue to storage after network failure',
      () async {
        when(mockStorageManager.getInstallId()).thenReturn('inst_1');
        when(
          mockNetworkManager.request<EventResponse>(
            endpoint: anyNamed('endpoint'),
            method: anyNamed('method'),
            body: anyNamed('body'),
            fromJson: anyNamed('fromJson'),
          ),
        ).thenThrow(NetworkError(Exception('fail')));

        when(mockQueue.peek()).thenReturn([]);
        when(
          mockStorageManager.saveEventQueue(any),
        ).thenAnswer((_) async => true);

        await expectLater(
          () => eventTracker.trackEvent('purchase'),
          throwsA(isA<NetworkError>()),
        );

        // Queue must be persisted after the failure
        verify(mockStorageManager.saveEventQueue(any)).called(1);
      },
    );

    test('EventTracker loads persisted queue from storage on creation',
        () async {
      final persistedEvent = EventRequest(
        installId: 'inst_1',
        eventName: 'persisted',
        eventData: {},
      );

      // Return persisted events from storage
      when(mockStorageManager.loadEventQueue()).thenReturn([persistedEvent]);

      // Clear interactions from setup so we can count calls specific to this test
      clearInteractions(mockStorageManager);

      // The real EventQueue is used here (not the mock)
      final realQueue = EventQueue();
      final tracker = EventTracker(
        networkManager: mockNetworkManager,
        storageManager: mockStorageManager,
        attributionContext: attributionContext,
        eventQueue: realQueue,
      );

      // Wait for constructor side-effects
      await Future.delayed(Duration.zero);

      expect(tracker.queuedEventCount, 1);
      verify(mockStorageManager.loadEventQueue()).called(1);
    });
  });
}
