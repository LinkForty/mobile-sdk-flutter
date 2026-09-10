import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/install_response.dart';
import 'package:linkforty_flutter/models/deep_link_data.dart';

void main() {
  group('InstallResponse', () {
    test('serializes to JSON correctly', () {
      final response = InstallResponse(
        installId: 'inst_123',
        attributed: true,
        confidenceScore: 95.0,
        matchedFactors: ['ip', 'ua'],
        deepLinkData: DeepLinkData(shortCode: 'abc'),
      );
      final json = response.toJson();
      expect(json['installId'], 'inst_123');
      expect(json['attributed'], isTrue);
      expect(json['matchedFactors'], ['ip', 'ua']);
      expect(json['deepLinkData']['shortCode'], 'abc');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'installId': 'inst_456',
        'attributed': false,
        'confidenceScore': 0.0,
        'matchedFactors': <String>[],
      };
      final response = InstallResponse.fromJson(json);
      expect(response.installId, 'inst_456');
      expect(response.attributed, isFalse);
      expect(response.matchedFactors, isEmpty);
      expect(response.deepLinkData, isNull);
    });

    // The backend returns `deepLinkData: {}` (not null) for organic installs.
    test('treats an empty deepLinkData object as no deep link', () {
      final response = InstallResponse.fromJson({
        'installId': 'inst_456',
        'attributed': false,
        'confidenceScore': 0.0,
        'matchedFactors': <String>[],
        'deepLinkData': <String, dynamic>{},
      });

      expect(response.installId, 'inst_456');
      expect(response.attributed, isFalse);
      expect(response.deepLinkData, isNull);
    });

    test('treats a null deepLinkData as no deep link', () {
      final response = InstallResponse.fromJson({
        'installId': 'inst_456',
        'attributed': false,
        'confidenceScore': 0.0,
        'matchedFactors': <String>[],
        'deepLinkData': null,
      });

      expect(response.deepLinkData, isNull);
    });

    // A deep link with no short code can't be routed to, so it is not worth
    // failing the whole response over.
    test('treats deepLinkData without a shortCode as no deep link', () {
      final response = InstallResponse.fromJson({
        'installId': 'inst_456',
        'attributed': false,
        'confidenceScore': 0.0,
        'matchedFactors': <String>[],
        'deepLinkData': {'iosUrl': 'myapp://product/456'},
      });

      expect(response.deepLinkData, isNull);
    });

    test('deserializes an attributed response with deep link data', () {
      final response = InstallResponse.fromJson({
        'installId': 'inst_789',
        'attributed': true,
        'confidenceScore': 85,
        'matchedFactors': ['ip', 'ua'],
        'deepLinkData': {
          'shortCode': 'abc123',
          'iosUrl': 'myapp://product/456',
          'deepLinkPath': '/product/456',
          'clickedAt': '2026-01-15T10:30:00Z',
        },
      });

      expect(response.attributed, isTrue);
      expect(response.confidenceScore, 85);
      expect(response.deepLinkData?.shortCode, 'abc123');
      expect(response.deepLinkData?.iosURL, 'myapp://product/456');
      expect(response.deepLinkData?.deepLinkPath, '/product/456');
      expect(response.deepLinkData?.clickedAt, isNotNull);
    });

    test('throws when a required field is missing', () {
      expect(
        () => InstallResponse.fromJson({
          'attributed': false,
          'confidenceScore': 0.0,
          'matchedFactors': <String>[],
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('equality works correctly', () {
      final res1 = InstallResponse(
        installId: '1',
        attributed: true,
        confidenceScore: 10,
        matchedFactors: ['a'],
      );
      final res2 = InstallResponse(
        installId: '1',
        attributed: true,
        confidenceScore: 10,
        matchedFactors: ['a'],
      );
      final res3 = InstallResponse(
        installId: '1',
        attributed: true,
        confidenceScore: 10,
        matchedFactors: ['b'], // Different factors
      );

      expect(res1, equals(res2));
      expect(res1, isNot(equals(res3)));
    });
  });
}
