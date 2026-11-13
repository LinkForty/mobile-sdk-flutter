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

    test(
      'holds a link that arrives before any callback, and delivers it once',
      () async {
        final uri = Uri.parse('https://example.com/abc');
        await handler.handleDeepLink(uri);

        final first = <Uri>[];
        final second = <Uri>[];
        final late = <Uri>[];
        handler.onDeepLink((u, _) => first.add(u));
        handler.onDeepLink((u, _) => second.add(u));
        await Future.delayed(Duration.zero);
        handler.onDeepLink((u, _) => late.add(u));
        await Future.delayed(Duration.zero);

        expect(first, [uri]);
        expect(second, [uri]);
        expect(late, isEmpty);
      },
    );

    test(
      'ignores the same URL handled again within the duplicate window',
      () async {
        final uri = Uri.parse('https://example.com/abc');
        final other = Uri.parse('https://example.com/def');
        final delivered = <Uri>[];
        handler.onDeepLink((u, _) => delivered.add(u));

        await handler.handleDeepLink(uri);
        await handler.handleDeepLink(uri);
        await handler.handleDeepLink(other);

        expect(delivered, [uri, other]);
      },
    );

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

    group('resolve request', () {
      final fingerprint = DeviceFingerprint(
        userAgent: 'ua',
        timezone: 'Europe/Paris',
        language: 'fr-FR',
        screenWidth: 390,
        screenHeight: 844,
        platform: 'ios',
        platformVersion: '18.1',
        appVersion: '1.0',
        attributionWindowHours: 168,
      );

      /// Handles [link] with mocks and returns the resolve endpoint requested.
      Future<String> resolveEndpointFor(String link) async {
        handler.configure(
          networkManager: mockNetworkManager,
          fingerprintCollector: mockFingerprintCollector,
          baseURL: Uri.parse('https://example.com'),
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
        ).thenAnswer((_) async => DeepLinkData(shortCode: 'abc'));

        handler.onDeepLink((u, d) {});
        await handler.handleDeepLink(Uri.parse(link));

        return verify(
              mockNetworkManager.request<DeepLinkData>(
                endpoint: captureAnyNamed('endpoint'),
                method: HttpMethod.get,
                fromJson: anyNamed('fromJson'),
              ),
            ).captured.single
            as String;
      }

      Map<String, String> queryOf(String endpoint) =>
          Uri.parse('https://example.com$endpoint').queryParameters;

      test("passes the link's query parameters with the fingerprint", () async {
        final endpoint = await resolveEndpointFor(
          'https://example.com/abc?os_id=u1&utm_campaign=winback',
        );

        expect(endpoint, startsWith('/api/sdk/v1/resolve/abc?'));
        expect(queryOf(endpoint), {
          'os_id': 'u1',
          'utm_campaign': 'winback',
          'fp_tz': 'Europe/Paris',
          'fp_lang': 'fr-FR',
          'fp_sw': '390',
          'fp_sh': '844',
          'fp_platform': 'ios',
          'fp_pv': '18.1',
        });
      });

      test(
        'keeps its own fingerprint over fp_ parameters on the link',
        () async {
          final query = queryOf(
            await resolveEndpointFor(
              'https://example.com/abc?fp_tz=evil&FP_LANG=evil&os_id=u1',
            ),
          );

          expect(query['fp_tz'], 'Europe/Paris');
          expect(query['fp_lang'], 'fr-FR');
          expect(query.containsKey('FP_LANG'), isFalse);
          expect(query['os_id'], 'u1');
        },
      );

      test('encodes values once', () async {
        final query = queryOf(
          await resolveEndpointFor(
            'https://example.com/abc?note=a%20b%26c&email=a%2Bb%40example.com',
          ),
        );

        expect(query['note'], 'a b&c');
        expect(query['email'], 'a+b@example.com');
      });

      test(
        'reads a literal "+" in the link as a space, as a server does',
        () async {
          final query = queryOf(
            await resolveEndpointFor(
              'https://example.com/abc?iterable_id=a+b%40x.com&email=c%2Bd%40x.com',
            ),
          );

          expect(query['iterable_id'], 'a b@x.com');
          expect(query['email'], 'c+d@x.com');
        },
      );

      test('sends only the fingerprint for a link with no query', () async {
        final query = queryOf(
          await resolveEndpointFor('https://example.com/abc'),
        );

        expect(query.keys.toList()..sort(), [
          'fp_lang',
          'fp_platform',
          'fp_pv',
          'fp_sh',
          'fp_sw',
          'fp_tz',
        ]);
      });
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
