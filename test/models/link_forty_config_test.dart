import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/link_forty_config.dart';

void main() {
  group('LinkFortyConfig', () {
    test('validates valid configuration', () {
      final config = LinkFortyConfig(
        baseURL: Uri.parse('https://example.com'),
        apiKey: 'test-key',
      );
      expect(() => config.validate(), returnsNormally);
    });

    test('validates valid localhost configuration (HTTP)', () {
      final config = LinkFortyConfig(
        baseURL: Uri.parse('http://localhost:8080'),
      );
      expect(() => config.validate(), returnsNormally);
    });

    test('throws error for non-HTTPS URL', () {
      final config = LinkFortyConfig(baseURL: Uri.parse('http://example.com'));
      expect(() => config.validate(), throwsA(isA<LinkFortyException>()));
    });

    test('throws error for invalid attribution window', () {
      final config = LinkFortyConfig(
        baseURL: Uri.parse('https://example.com'),
        attributionWindowHours: 0,
      );
      expect(() => config.validate(), throwsA(isA<LinkFortyException>()));
    });

    test('equality works correctly', () {
      final config1 = LinkFortyConfig(
        baseURL: Uri.parse('https://example.com'),
        apiKey: 'key',
      );
      final config2 = LinkFortyConfig(
        baseURL: Uri.parse('https://example.com'),
        apiKey: 'key',
      );
      final config3 = LinkFortyConfig(
        baseURL: Uri.parse('https://other.com'),
        apiKey: 'key',
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });
  });
}
