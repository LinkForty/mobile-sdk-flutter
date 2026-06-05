import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:linkforty_flutter/link_forty.dart';
import 'package:linkforty_flutter/models/link_forty_config.dart';
import 'package:linkforty_flutter/models/install_response.dart';
import 'package:linkforty_flutter/models/deep_link_data.dart';
import 'package:linkforty_flutter/models/create_link_options.dart';
import 'package:linkforty_flutter/models/dashboard_create_link_response.dart';
import 'package:linkforty_flutter/network/network_manager.dart';
import 'package:linkforty_flutter/storage/storage_manager.dart';
import 'package:linkforty_flutter/fingerprint/fingerprint_collector.dart';
import 'package:linkforty_flutter/fingerprint/device_fingerprint.dart';
import 'package:linkforty_flutter/network/http_method.dart';
import 'package:linkforty_flutter/errors/link_forty_error.dart';

import 'link_forty_test.mocks.dart';

@GenerateMocks([
  NetworkManagerProtocol,
  StorageManagerProtocol,
  FingerprintCollectorProtocol,
])
void main() {
  late MockNetworkManagerProtocol mockNetworkManager;
  late MockStorageManagerProtocol mockStorageManager;
  late MockFingerprintCollectorProtocol mockFingerprintCollector;
  late LinkFortyConfig config;

  setUp(() {
    mockNetworkManager = MockNetworkManagerProtocol();
    mockStorageManager = MockStorageManagerProtocol();
    mockFingerprintCollector = MockFingerprintCollectorProtocol();
    config = LinkFortyConfig(
      baseURL: Uri.parse('https://example.com'),
      apiKey: 'test_key',
    );

    // Default storage stubs (first launch state)
    when(mockStorageManager.getInstallId()).thenReturn(null);
    when(mockStorageManager.getInstallData()).thenReturn(null);
    when(mockStorageManager.loadEventQueue()).thenReturn([]);
    when(mockStorageManager.saveInstallId(any)).thenAnswer((_) async => true);
    when(mockStorageManager.saveInstallData(any)).thenAnswer((_) async => true);
    when(mockStorageManager.setHasLaunched()).thenAnswer((_) async => true);

    LinkForty.instanceOrNull?.reset();
  });

  tearDown(() {
    LinkForty.instanceOrNull?.reset();
  });

  group('LinkForty', () {
    test('initialize sets up SDK and reports install', () async {
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
      final installResponse = InstallResponse(
        installId: 'inst_1',
        attributed: true,
        confidenceScore: 100,
        matchedFactors: [],
        deepLinkData: DeepLinkData(shortCode: 'abc'),
      );

      when(
        mockFingerprintCollector.collectFingerprint(
          attributionWindowHours: anyNamed('attributionWindowHours'),
          deviceId: anyNamed('deviceId'),
        ),
      ).thenAnswer((_) async => fingerprint);

      when(
        mockNetworkManager.request<InstallResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => installResponse);

      when(mockStorageManager.saveInstallId(any)).thenAnswer((_) async => true);
      when(
        mockStorageManager.saveInstallData(any),
      ).thenAnswer((_) async => true);
      when(mockStorageManager.setHasLaunched()).thenAnswer((_) async => true);
      when(mockStorageManager.loadEventQueue()).thenReturn([]);
      when(mockStorageManager.getInstallId()).thenReturn(null);

      final response = await LinkForty.initialize(
        config: config,
        networkManager: mockNetworkManager,
        storageManager: mockStorageManager,
        fingerprintCollector: mockFingerprintCollector,
      );

      expect(LinkForty.instance, isNotNull);
      expect(response.installId, 'inst_1');

      verify(
        mockNetworkManager.request<InstallResponse>(
          endpoint: '/api/sdk/v1/install',
          method: HttpMethod.post,
          body: fingerprint.toJson(),
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);
    });

    test('trackEvent checks initialization', () async {
      // Not initialized
      await expectLater(
        () => LinkForty.instance,
        throwsA(isA<NotInitializedError>()),
      );
    });

    // We can add more integration tests here, but since we tested Managers individually,
    // verifying `initialize` wiring is the most important part.

    test('createLink works', () async {
      // Initialize first
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
      final installResponse = InstallResponse(
        installId: 'inst_1',
        attributed: false,
        confidenceScore: 0,
        matchedFactors: [],
      );

      when(
        mockFingerprintCollector.collectFingerprint(
          attributionWindowHours: anyNamed('attributionWindowHours'),
          deviceId: anyNamed('deviceId'),
        ),
      ).thenAnswer((_) async => fingerprint);
      when(
        mockNetworkManager.request<InstallResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => installResponse);
      when(mockStorageManager.saveInstallId(any)).thenAnswer((_) async => true);
      when(mockStorageManager.setHasLaunched()).thenAnswer((_) async => true);
      when(mockStorageManager.loadEventQueue()).thenReturn([]);
      when(mockStorageManager.getInstallId()).thenReturn(null);

      await LinkForty.initialize(
        config: config,
        networkManager: mockNetworkManager,
        storageManager: mockStorageManager,
        fingerprintCollector: mockFingerprintCollector,
      );

      // Create Link
      final options = CreateLinkOptions(templateId: 'template_123');
      final result = DashboardCreateLinkResponse(id: '123', shortCode: 'abc');

      when(
        mockNetworkManager.request<DashboardCreateLinkResponse>(
          endpoint: anyNamed('endpoint'),
          method: anyNamed('method'),
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => result);

      final linkResult = await LinkForty.instance.createLink(options);

      expect(linkResult.shortCode, 'abc');
      verify(
        mockNetworkManager.request(
          endpoint: '/api/links',
          method: HttpMethod.post,
          body: options.toJson(),
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);
    });
  });
}
