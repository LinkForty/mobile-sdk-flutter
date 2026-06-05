import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/create_link_result.dart';

void main() {
  group('CreateLinkResult', () {
    test('serializes and deserializes correctly', () {
      const result = CreateLinkResult(
        url: 'https://short.link/abc',
        shortCode: 'abc',
        linkId: '123',
      );
      final json = result.toJson();
      expect(json['url'], 'https://short.link/abc');

      final fromJson = CreateLinkResult.fromJson(json);
      expect(fromJson, equals(result));
    });

    test('equality works correctly', () {
      const result1 = CreateLinkResult(
        url: 'https://a.com/1',
        shortCode: '1',
        linkId: 'id1',
      );
      const result2 = CreateLinkResult(
        url: 'https://a.com/1',
        shortCode: '1',
        linkId: 'id1',
      );
      const result3 = CreateLinkResult(
        url: 'https://a.com/2',
        shortCode: '2',
        linkId: 'id2',
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });
  });
}
