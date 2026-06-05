import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/create_link_options.dart';
import 'package:linkforty_flutter/models/utm_parameters.dart';

void main() {
  group('CreateLinkOptions', () {
    test('serializes to JSON correctly', () {
      const options = CreateLinkOptions(
        templateId: 'tmpl_123',
        deepLinkParameters: {'route': 'home'},
        title: 'New Link',
        utmParameters: UTMParameters(source: 'test'),
      );
      final json = options.toJson();
      expect(json['templateId'], 'tmpl_123');
      expect(json['deepLinkParameters'], {'route': 'home'});
      expect(json['title'], 'New Link');
      expect(json['utmParameters']['source'], 'test');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'templateSlug': 'promo',
        'customCode': 'my-code',
        'utmParameters': {'medium': 'email'},
      };
      final options = CreateLinkOptions.fromJson(json);
      expect(options.templateSlug, 'promo');
      expect(options.customCode, 'my-code');
      expect(options.utmParameters?.medium, 'email');
    });
  });
}
