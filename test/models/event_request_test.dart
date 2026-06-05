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
  });
}
