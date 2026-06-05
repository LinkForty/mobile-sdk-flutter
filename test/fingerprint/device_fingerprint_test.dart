import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/fingerprint/device_fingerprint.dart';

void main() {
  group('DeviceFingerprint', () {
    test('supports value equality', () {
      final fp1 = DeviceFingerprint(
        userAgent: 'ua',
        timezone: 'tz',
        language: 'en',
        screenWidth: 100,
        screenHeight: 200,
        platform: 'TestOS',
        platformVersion: '1.0',
        appVersion: '1.0.0',
        attributionWindowHours: 24,
      );

      final fp2 = DeviceFingerprint(
        userAgent: 'ua',
        timezone: 'tz',
        language: 'en',
        screenWidth: 100,
        screenHeight: 200,
        platform: 'TestOS',
        platformVersion: '1.0',
        appVersion: '1.0.0',
        attributionWindowHours: 24,
      );

      expect(fp1, equals(fp2));
      expect(fp1.hashCode, equals(fp2.hashCode));
    });

    test('toJson and fromJson work correctly', () {
      final fp = DeviceFingerprint(
        userAgent: 'ua',
        timezone: 'tz',
        language: 'en',
        screenWidth: 100,
        screenHeight: 200,
        platform: 'TestOS',
        platformVersion: '1.0',
        appVersion: '1.0.0',
        deviceId: 'device123',
        attributionWindowHours: 24,
      );

      final json = fp.toJson();
      expect(json['userAgent'], 'ua');
      expect(json['deviceId'], 'device123');

      final deserialized = DeviceFingerprint.fromJson(json);
      expect(deserialized, equals(fp));
    });

    test('toString contains key fields', () {
      final fp = DeviceFingerprint(
        userAgent: 'ua',
        timezone: 'tz',
        language: 'en',
        screenWidth: 100,
        screenHeight: 200,
        platform: 'TestOS',
        platformVersion: '1.0',
        appVersion: '1.0.0',
        attributionWindowHours: 24,
      );

      expect(fp.toString(), contains('TestOS'));
      expect(fp.toString(), contains('1.0.0'));
    });
  });
}
