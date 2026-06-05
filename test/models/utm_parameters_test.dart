import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/utm_parameters.dart';

void main() {
  group('UTMParameters', () {
    test('serializes to JSON correctly', () {
      const utm = UTMParameters(
        source: 'google',
        medium: 'cpc',
        campaign: 'summer_sale',
        term: 'shoes',
        content: 'banner',
      );
      final json = utm.toJson();
      expect(json['source'], 'google');
      expect(json['medium'], 'cpc');
      expect(json['campaign'], 'summer_sale');
      expect(json['term'], 'shoes');
      expect(json['content'], 'banner');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'source': 'facebook',
        'medium': 'social',
        'campaign': 'launch',
      };
      final utm = UTMParameters.fromJson(json);
      expect(utm.source, 'facebook');
      expect(utm.medium, 'social');
      expect(utm.campaign, 'launch');
      expect(utm.term, isNull);
      expect(utm.content, isNull);
    });

    test('hasAnyParameter returns true if any parameter is set', () {
      const utm = UTMParameters(source: 'google');
      expect(utm.hasAnyParameter, isTrue);
    });

    test('hasAnyParameter returns false if no parameter is set', () {
      const utm = UTMParameters();
      expect(utm.hasAnyParameter, isFalse);
    });

    test('equality works correctly', () {
      const utm1 = UTMParameters(source: 'google', medium: 'cpc');
      const utm2 = UTMParameters(source: 'google', medium: 'cpc');
      const utm3 = UTMParameters(source: 'facebook', medium: 'cpc');

      expect(utm1, equals(utm2));
      expect(utm1, isNot(equals(utm3)));
    });
  });
}
