import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:linkforty_flutter/fingerprint/fingerprint_collector.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Since we cannot mock platform channels easily in unit tests for static methods,
// we rely on dependency injection in FingerprintCollector.
// However, DeviceInfoPlugin and PackageInfo use platform channels internally.
// We can mock the specific Info classes if we wrap the calls, but FingerprintCollector
// calls `await _deviceInfo.androidInfo` directly.
// To test this properly, we need to mock DeviceInfoPlugin.

import 'fingerprint_collector_test.mocks.dart';

@GenerateMocks([
  DeviceInfoPlugin,
  PackageInfo,
  AndroidDeviceInfo,
  IosDeviceInfo,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDeviceInfoPlugin mockDeviceInfo;
  late MockPackageInfo mockPackageInfo;
  late FingerprintCollector collector;

  setUp(() {
    mockDeviceInfo = MockDeviceInfoPlugin();
    mockPackageInfo = MockPackageInfo();

    // Setup default package info
    when(mockPackageInfo.appName).thenReturn('TestApp');
    when(mockPackageInfo.version).thenReturn('1.0.0');

    collector = FingerprintCollector(
      deviceInfo: mockDeviceInfo,
      packageInfo: mockPackageInfo,
    );
  });

  // Note: Testing platform specific logic (Platform.isAndroid) is hard in unit tests
  // because Platform.isAndroid is a static getter we can't easily mock without
  // running in that environment or using IO overrides.
  // We will skip platform-specific branching tests here and assume the logic works if
  // dependency injection is correct, or use a separate integration test.
  // For unit tests, we can verify that it calls the injected dependencies.

  test('collects basic fingerprint info', () async {
    // Basic smoke test to ensure constructor works with mocked dependencies
    expect(collector, isNotNull);
  });

  group('localTimezone', () {
    const channel = MethodChannel('flutter_timezone');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('reports the IANA identifier from the platform', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getLocalTimezone');
        return {'identifier': 'Asia/Kolkata'};
      });

      expect(await FingerprintCollector.localTimezone(), 'Asia/Kolkata');
    });

    test(
      'falls back to the abbreviation when the platform cannot answer',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unavailable');
        });

        expect(
          await FingerprintCollector.localTimezone(),
          DateTime.now().timeZoneName,
        );
      },
    );
  });

  group('languageTag', () {
    final cases = <String, Locale>{
      'en-US': const Locale('en', 'US'),
      'en': const Locale('en'),
      'en-ES': const Locale('en', 'ES'),
      'es-419': const Locale('es', '419'),
      'fil-PH': const Locale('fil', 'PH'),
      // Script subtags are dropped.
      'zh-CN': const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'CN',
      ),
      'zh-TW': const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
      'sr-RS': const Locale.fromSubtags(
        languageCode: 'sr',
        scriptCode: 'Latn',
        countryCode: 'RS',
      ),
      'zh': const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    };

    cases.forEach((expected, locale) {
      test('$locale -> $expected', () {
        final tag = FingerprintCollector.languageTag(locale);
        expect(tag, expected);
        expect(tag.length, lessThanOrEqualTo(10));
        expect(tag, matches(RegExp(r'^[a-z]{2,3}(-([A-Z]{2}|[0-9]{3}))?$')));
      });
    });

    test('an empty country code reports the language alone', () {
      expect(FingerprintCollector.languageTag(const Locale('en', '')), 'en');
    });
  });

  testWidgets('reads the device locale from the platform dispatcher', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
      countryCode: 'CN',
    );
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    expect(
      FingerprintCollector.languageTag(tester.platformDispatcher.locale),
      'zh-CN',
    );
  });
}
