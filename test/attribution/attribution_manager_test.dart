import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:linkforty_flutter/attribution/attribution_manager.dart';
import 'package:linkforty_flutter/network/network_manager.dart';
import 'package:linkforty_flutter/storage/storage_manager.dart';
import 'package:linkforty_flutter/fingerprint/fingerprint_collector.dart';
import 'package:linkforty_flutter/models/install_response.dart';
import 'package:linkforty_flutter/models/deep_link_data.dart';
import 'package:linkforty_flutter/fingerprint/device_fingerprint.dart';
import 'package:linkforty_flutter/network/http_method.dart';
import 'package:linkforty_flutter/errors/link_forty_error.dart';

import 'attribution_manager_test.mocks.dart';

@GenerateMocks([
  NetworkManagerProtocol,
  StorageManagerProtocol,
  FingerprintCollectorProtocol,
])
void main() {
  late MockNetworkManagerProtocol mockNetworkManager;
  late MockStorageManagerProtocol mockStorageManager;
  late MockFingerprintCollectorProtocol mockFingerprintCollector;
  late AttributionManager attributionManager;

  setUp(() {
    mockNetworkManager = MockNetworkManagerProtocol();
    mockStorageManager = MockStorageManagerProtocol();
    mockFingerprintCollector = MockFingerprintCollectorProtocol();

    // Setup default storage behavior (first launch)
    when(mockStorageManager.getInstallId()).thenReturn(null);
    when(mockStorageManager.getInstallData()).thenReturn(null);
    when(mockStorageManager.saveInstallId(any)).thenAnswer((_) async => true);
    when(mockStorageManager.saveInstallData(any)).thenAnswer((_) async => true);
    when(mockStorageManager.setHasLaunched()).thenAnswer((_) async => true);

    attributionManager = AttributionManager(
      networkManager: mockNetworkManager,
      storageManager: mockStorageManager,
      fingerprintCollector: mockFingerprintCollector,
    );
  });

  group('AttributionManager', () {
    test('reportInstall collects fingerprint and sends request', () async {
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

      final result = await attributionManager.reportInstall(
        attributionWindowHours: 168,
      );

      verify(
        mockFingerprintCollector.collectFingerprint(
          attributionWindowHours: 168,
          deviceId: null,
        ),
      ).called(1);

      verify(
        mockNetworkManager.request<InstallResponse>(
          endpoint: '/api/sdk/v1/install',
          method: HttpMethod.post,
          body: fingerprint.toJson(),
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);

      verify(mockStorageManager.saveInstallId('inst_1')).called(1);
      verify(
        mockStorageManager.saveInstallData(
          argThat(
            isA<DeepLinkData>().having((d) => d.shortCode, 'shortCode', 'abc'),
          ),
        ),
      ).called(1);
      verify(mockStorageManager.setHasLaunched()).called(1);

      expect(result, equals(installResponse));
    });

    test('reportInstall handles organic install (no deep link data)', () async {
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
        installId: 'inst_2',
        attributed: false,
        confidenceScore: 0,
        matchedFactors: [],
        deepLinkData: null,
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

      await attributionManager.reportInstall(attributionWindowHours: 168);

      verify(mockStorageManager.saveInstallId('inst_2')).called(1);
      verifyNever(mockStorageManager.saveInstallData(any));
    });

    test('getInstallId returns stored ID', () {
      when(mockStorageManager.getInstallId()).thenReturn('id');
      expect(attributionManager.getInstallId(), 'id');
    });

    test('getInstallData returns stored data', () {
      final data = DeepLinkData(shortCode: 'abc');
      when(mockStorageManager.getInstallData()).thenReturn(data);
      expect(attributionManager.getInstallData(), data);
    });

    test('isFirstLaunch returns stored value', () {
      when(mockStorageManager.isFirstLaunch()).thenReturn(true);
      expect(attributionManager.isFirstLaunch(), isTrue);
    });

    test('clearData clears storage', () async {
      when(mockStorageManager.clearAll()).thenAnswer((_) async => true);
      await attributionManager.clearData();
      verify(mockStorageManager.clearAll()).called(1);
    });

    test(
      'subsequent launch: returns cached data without network call',
      () async {
        // installId already stored → subsequent launch
        when(mockStorageManager.getInstallId()).thenReturn('inst_cached');
        final cachedData = DeepLinkData(shortCode: 'xyz');
        when(mockStorageManager.getInstallData()).thenReturn(cachedData);

        final result = await attributionManager.reportInstall(
          attributionWindowHours: 168,
        );

        expect(result.installId, 'inst_cached');
        expect(result.attributed, isTrue);
        expect(result.deepLinkData?.shortCode, 'xyz');

        // Must not make any network call
        verifyNever(
          mockNetworkManager.request<InstallResponse>(
            endpoint: anyNamed('endpoint'),
            method: anyNamed('method'),
            body: anyNamed('body'),
            fromJson: anyNamed('fromJson'),
          ),
        );
      },
    );

    test(
      'first launch network failure: returns organic response, does not throw',
      () async {
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

        // No stored installId → first launch
        when(mockStorageManager.getInstallId()).thenReturn(null);

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
        ).thenThrow(NetworkError(Exception('no network')));

        // Should NOT throw
        final result = await attributionManager.reportInstall(
          attributionWindowHours: 168,
        );

        expect(result.attributed, isFalse);
        expect(result.installId, '');

        // installId must NOT be persisted on failure
        verifyNever(mockStorageManager.saveInstallId(any));
        verifyNever(mockStorageManager.setHasLaunched());
      },
    );
  });
}
