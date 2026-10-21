import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/event_response.dart';

void main() {
  group('EventResponse', () {
    test('decodes the event endpoint reply', () {
      final response = EventResponse.fromJson({
        'eventId': '8e6c3f1e-1b2a-4c3d-9e8f-0a1b2c3d4e5f',
        'acknowledged': true,
      });
      expect(response.eventId, '8e6c3f1e-1b2a-4c3d-9e8f-0a1b2c3d4e5f');
      expect(response.acknowledged, isTrue);
    });

    test('decodes a reply without either field', () {
      final response = EventResponse.fromJson(const {});
      expect(response.eventId, isNull);
      expect(response.acknowledged, isNull);
    });

    test('round-trips through JSON', () {
      const response = EventResponse(eventId: 'e1', acknowledged: true);
      expect(EventResponse.fromJson(response.toJson()), equals(response));
    });
  });
}
