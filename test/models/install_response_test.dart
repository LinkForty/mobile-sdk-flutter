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

    test('reads attributionMethod and competingLinks on a match', () {
      final response = InstallResponse.fromJson({
        'installId': 'inst_789',
        'attributed': true,
        'confidenceScore': 85,
        'matchedFactors': ['ip', 'ua'],
        'attributionMethod': 'fingerprint',
        'competingLinks': 2,
        'deepLinkData': {
          'shortCode': 'abc123',
          'confidenceScore': 85,
          'matchedFactors': ['ip', 'ua'],
          'attributionMethod': 'fingerprint',
          'competingLinks': 2,
        },
      });

      expect(response.attributionMethod, 'fingerprint');
      expect(response.competingLinks, 2);
      expect(response.deepLinkData?.confidenceScore, 85.0);
      expect(response.deepLinkData?.matchedFactors, ['ip', 'ua']);
      expect(response.deepLinkData?.attributionMethod, 'fingerprint');
      expect(response.deepLinkData?.competingLinks, 2);
    });

    test('reads an organic response with attributionMethod none', () {
      final response = InstallResponse.fromJson({
        'installId': 'inst_456',
        'attributed': false,
        'confidenceScore': 0,
        'matchedFactors': <String>[],
        'attributionMethod': 'none',
        'competingLinks': 0,
        'deepLinkData': <String, dynamic>{},
      });

      expect(response.attributionMethod, 'none');
      expect(response.competingLinks, 0);
      expect(response.deepLinkData, isNull);
    });

    test('leaves attributionMethod and competingLinks null when absent', () {
      final response = InstallResponse.fromJson({
        'installId': 'inst_456',
        'attributed': false,
        'confidenceScore': 0,
        'matchedFactors': <String>[],
      });

      expect(response.attributionMethod, isNull);
      expect(response.competingLinks, isNull);
    });

    test('reads competingLinks sent as a double as an int', () {
      final response = InstallResponse.fromJson({
        'installId': 'inst_456',
        'attributed': true,
        'confidenceScore': 70,
        'matchedFactors': <String>[],
        'competingLinks': 3.0,
      });

      expect(response.competingLinks, 3);
      expect(response.competingLinks, isA<int>());
    });

    test('reads unexpected certainty values as null instead of failing', () {
      final response = InstallResponse.fromJson({
        'installId': 'inst_456',
        'attributed': true,
        'confidenceScore': 70,
        'matchedFactors': <String>[],
        'attributionMethod': 7,
        'competingLinks': 'two',
      });

      expect(response.attributionMethod, isNull);
      expect(response.competingLinks, isNull);
    });

    test('round-trips the certainty fields through JSON', () {
      const response = InstallResponse(
        installId: 'inst_1',
        attributed: true,
        confidenceScore: 90,
        matchedFactors: ['ip'],
        attributionMethod: 'fingerprint',
        competingLinks: 1,
      );

      expect(InstallResponse.fromJson(response.toJson()), equals(response));
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
      expect(
        res1,
        isNot(
          equals(
            InstallResponse(
              installId: '1',
              attributed: true,
              confidenceScore: 10,
              matchedFactors: ['a'],
              competingLinks: 1,
            ),
          ),
        ),
      );
    });
  });
}
