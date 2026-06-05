import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/event_response.dart';

void main() {
  group('EventResponse', () {
    test('serializes and deserializes correctly', () {
      const response = EventResponse(success: true);
      final json = response.toJson();
      expect(json['success'], isTrue);

      final fromJson = EventResponse.fromJson(json);
      expect(fromJson, equals(response));
    });
  });
}
