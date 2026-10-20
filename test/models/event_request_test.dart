import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/event_request.dart';

void main() {
  group('EventRequest', () {
    test('serializes to JSON correctly', () {
      final request = EventRequest(
        installId: 'inst_1',
        eventName: 'test_event',
        eventData: {'price': 10.5, 'currency': 'USD'},
      );
      final json = request.toJson();
      expect(json['installId'], 'inst_1');
      expect(json['eventName'], 'test_event');
      expect(json['eventData']['price'], 10.5);
      expect(json['timestamp'], isNotNull);
    });

    test('sanitizes nested data structures', () {
      final request = EventRequest(
        installId: 'id',
        eventName: 'name',
        eventData: {
          'user': {
            'name': 'John',
            'tags': ['a', 'b'],
            'meta': {'verified': true},
          },
          'items': [
            {'id': 1},
            {'id': 2},
          ],
        },
      );
      final json = request.toJson();
      final data = json['eventData'] as Map<String, dynamic>;

      expect(data['user']['name'], 'John');
      expect(data['user']['tags'], ['a', 'b']);
      expect(data['items'][0]['id'], 1);
    });

    test('deep equality works correctly', () {
      final req1 = EventRequest(
        installId: '1',
        eventName: 'a',
        eventData: {
          'x': [1, 2],
        },
      );
      final req2 = EventRequest(
        installId: '1',
        eventName: 'a',
        eventData: {
          'x': [1, 2],
        },
        timestamp: DateTime.parse(req1.timestamp),
      );
      final req3 = EventRequest(
        installId: '1',
        eventName: 'a',
        eventData: {
          'x': [1, 3],
        }, // Different data
        timestamp: DateTime.parse(req1.timestamp),
      );

      expect(req1, equals(req2));
      expect(req1, isNot(equals(req3)));
    });

    test('timestamp is formatted in UTC ISO 8601 with Z suffix', () {
      final request = EventRequest(
        installId: 'inst_1',
        eventName: 'test_event',
        eventData: {},
      );
      expect(request.timestamp.endsWith('Z'), isTrue);
    });

    test('custom timestamp is converted to UTC ISO 8601 with Z suffix', () {
      final localTime = DateTime(2026, 9, 15, 12, 35, 19);
      final request = EventRequest(
        installId: 'inst_1',
        eventName: 'test_event',
        eventData: {},
        timestamp: localTime,
      );
      expect(request.timestamp.endsWith('Z'), isTrue);
      expect(request.timestamp, localTime.toUtc().toIso8601String());
    });

    test('omits null attribution and session keys from JSON', () {
      final request = EventRequest(
        installId: 'inst_1',
        eventName: 'organic_event',
        eventData: {'screen': 'home'},
      );
      final json = request.toJson();

      expect(json.containsKey('attributedLinkId'), isFalse);
      expect(json.containsKey('attributedClickId'), isFalse);
      expect(json.containsKey('linkOpenedAt'), isFalse);
      expect(json.containsKey('sessionId'), isFalse);
    });

    test('includes attribution and session keys when provided', () {
      final request = EventRequest(
        installId: 'inst_1',
        eventName: 'attributed_event',
        eventData: {'screen': 'product'},
        attributedLinkId: 'link_123',
        attributedClickId: 'click_456',
        linkOpenedAt: '2026-09-15T12:00:00.000Z',
        sessionId: 'sess_789',
      );
      final json = request.toJson();

      expect(json['attributedLinkId'], 'link_123');
      expect(json['attributedClickId'], 'click_456');
      expect(json['linkOpenedAt'], '2026-09-15T12:00:00.000Z');
      expect(json['sessionId'], 'sess_789');
    });
  });
}
