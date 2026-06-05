import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:linkforty_flutter/deeplink/deeplink_handler.dart';
import 'package:linkforty_flutter/network/network_manager.dart';
import 'package:linkforty_flutter/fingerprint/fingerprint_collector.dart';
import 'package:linkforty_flutter/models/deep_link_data.dart';
import 'package:linkforty_flutter/fingerprint/device_fingerprint.dart';
import 'package:linkforty_flutter/network/http_method.dart';

import 'deeplink_handler_test.mocks.dart';

@GenerateMocks([NetworkManagerProtocol, FingerprintCollectorProtocol])
void main() {
  late MockNetworkManagerProtocol mockNetworkManager;
  late MockFingerprintCollectorProtocol mockFingerprintCollector;
  late DeepLinkHandler handler;

  setUp(() {
    mockNetworkManager = MockNetworkManagerProtocol();
    mockFingerprintCollector = MockFingerprintCollectorProtocol();
    handler = DeepLinkHandler();
  });

  group('DeepLinkHandler', () {
    test(
      'delivers deferred deep link immediately if listener attached',
      () async {
        final data = DeepLinkData(shortCode: 'abc');
        DeepLinkData? deliveredData;

        handler.onDeferredDeepLink((d) => deliveredData = d);
        await handler.deliverDeferredDeepLink(data);

        expect(deliveredData, data);
      },
    );

    test('caches deferred deep link and delivers to late listener', () async {
      final data = DeepLinkData(shortCode: 'abc');

      await handler.deliverDeferredDeepLink(data);

      DeepLinkData? deliveredData;
      handler.onDeferredDeepLink((d) => deliveredData = d);

      // Allow microtask to run
      await Future.delayed(Duration.zero);
      expect(deliveredData, data);
    });

    test('handleDeepLink parses local URL correctly', () async {
      final uri = Uri.parse('https://example.com/abc');
      Uri? deliveredUri;
      DeepLinkData? deliveredData;

      handler.onDeepLink((u, d) {
        deliveredUri = u;
        deliveredData = d;
      });

      await handler.handleDeepLink(uri);

      expect(deliveredUri, uri);
      expect(deliveredData?.shortCode, 'abc');
    });

    test('handleDeepLink resolves via server if configured', () async {
      handler.configure(
        networkManager: mockNetworkManager,
        fingerprintCollector: mockFingerprintCollector,
        baseURL: Uri.parse('https://example.com'),
      );

      final uri = Uri.parse('https://example.com/abc');
      final resolvedData = DeepLinkData(
        shortCode: 'abc',
        deepLinkPath: '/resolved',
      );

      final fingerprint = DeviceFingerprint(
        userAgent: 'ua',
        timezone: 'tz',
        language: 'en',
        screenWidth: 100,
        screenHeight: 100,
        platform: 'test',
        platformVersion: '1.0',
        appVersion: '1.0',
        attributionWindowHours: 168,
      );

      when(
        mockFingerprintCollector.collectFingerprint(
          attributionWindowHours: anyNamed('attributionWindowHours'),
          deviceId: anyNamed('deviceId'),
        ),
      ).thenAnswer((_) async => fingerprint);

      when(
        mockNetworkManager.request<DeepLinkData>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => resolvedData);

      DeepLinkData? deliveredData;
      handler.onDeepLink((u, d) => deliveredData = d);

      await handler.handleDeepLink(uri);

      verify(
        mockNetworkManager.request<DeepLinkData>(
          endpoint: argThat(
            startsWith('/api/sdk/v1/resolve/abc'),
            named: 'endpoint',
          ),
          method: HttpMethod.get,
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);

      expect(deliveredData?.deepLinkPath, '/resolved');
    });

    test('handleDeepLink falls back to local if server fails', () async {
      handler.configure(
        networkManager: mockNetworkManager,
        fingerprintCollector: mockFingerprintCollector,
        baseURL: Uri.parse('https://example.com'),
      );

      final uri = Uri.parse('https://example.com/abc');
      final fingerprint = DeviceFingerprint(
        userAgent: 'ua',
        timezone: 'tz',
        language: 'en',
        screenWidth: 100,
        screenHeight: 100,
        platform: 'test',
        platformVersion: '1.0',
        appVersion: '1.0',
        attributionWindowHours: 168,
      );

      when(
        mockFingerprintCollector.collectFingerprint(
          attributionWindowHours: anyNamed('attributionWindowHours'),
          deviceId: anyNamed('deviceId'),
        ),
      ).thenAnswer((_) async => fingerprint);

      when(
        mockNetworkManager.request<DeepLinkData>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(Exception('fail'));

      DeepLinkData? deliveredData;
      handler.onDeepLink((u, d) => deliveredData = d);

      await handler.handleDeepLink(uri);

      expect(deliveredData?.shortCode, 'abc'); // Local parse
    });
  });
}
