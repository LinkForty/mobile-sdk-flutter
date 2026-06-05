import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/deep_link_data.dart';
import 'package:linkforty_flutter/models/utm_parameters.dart';

void main() {
  group('DeepLinkData', () {
    test('serializes to JSON correctly', () {
      final now = DateTime.now();
      final data = DeepLinkData(
        shortCode: 'abc123',
        iosURL: 'https://example.com/ios',
        androidURL: 'https://example.com/android',
        webURL: 'https://example.com',
        utmParameters: UTMParameters(source: 'email'),
        customParameters: {'promo': 'true'},
        deepLinkPath: '/product/1',
        appScheme: 'myapp',
        clickedAt: now,
        linkId: 'link_1',
      );
      final json = data.toJson();
      expect(json['shortCode'], 'abc123');
      expect(json['iosUrl'], 'https://example.com/ios');
      expect(json['clickedAt'], now.toIso8601String());
      expect(json['utmParameters']['source'], 'email');
      expect(json['customParameters']['promo'], 'true');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'shortCode': 'xyz789',
        'webUrl': 'https://example.com',
        'clickedAt': '2023-01-01T12:00:00.000Z',
        'customParameters': {'user_id': '10'},
      };
      final data = DeepLinkData.fromJson(json);
      expect(data.shortCode, 'xyz789');
      expect(data.webURL, 'https://example.com');
      expect(data.clickedAt?.year, 2023);
      expect(data.customParameters?['user_id'], '10');
    });

    test('handles invalid date format gracefully', () {
      final json = {'shortCode': 'abc', 'clickedAt': 'invalid-date'};
      final data = DeepLinkData.fromJson(json);
      expect(data.clickedAt, isNull);
    });

    test('equality works correctly', () {
      final data1 = DeepLinkData(shortCode: 'abc', linkId: '1');
      final data2 = DeepLinkData(shortCode: 'abc', linkId: '1');
      final data3 = DeepLinkData(shortCode: 'abc', linkId: '2');

      expect(data1, equals(data2));
      expect(data1, isNot(equals(data3)));
    });
  });
}
