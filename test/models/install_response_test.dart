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
