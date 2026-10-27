// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import '../link_forty_logger.dart';
import '../models/install_response.dart';
import '../models/deep_link_data.dart';
import '../network/network_manager.dart';
import '../network/http_method.dart';
import '../storage/storage_manager.dart';
import '../fingerprint/fingerprint_collector.dart';
import '../errors/link_forty_error.dart';
import 'install_referrer.dart';

/// Manages app install attribution and initial deferred deep link retrieval.
///
/// This manager is responsible for identifying how a user first found and
/// installed the app (e.g., via a specific LinkForty short link).
class AttributionManager {
  final NetworkManagerProtocol _networkManager;
  final StorageManagerProtocol _storageManager;
  final FingerprintCollectorProtocol _fingerprintCollector;
  final InstallReferrerReader? _readInstallReferrer;

  /// Creates an attribution manager
  ///
  /// - [networkManager]: Network manager for API requests
  /// - [storageManager]: Storage manager for caching data
  /// - [fingerprintCollector]: Fingerprint collector for device data
  /// - [readInstallReferrer]: Reads the Google Play install referrer; null
  ///   sends none
  AttributionManager({
    required NetworkManagerProtocol networkManager,
    required StorageManagerProtocol storageManager,
    required FingerprintCollectorProtocol fingerprintCollector,
    InstallReferrerReader? readInstallReferrer,
  }) : _networkManager = networkManager,
       _storageManager = storageManager,
       _fingerprintCollector = fingerprintCollector,
       _readInstallReferrer = readInstallReferrer;

  // MARK: - Install Attribution

  /// Reports a new app install to the LinkForty backend to retrieve attribution data.
  ///
  /// **Behavior:**
  /// - **First Launch:** If no [installId] is stored locally, it collects a device
  ///   fingerprint and performs a POST request to `/api/sdk/v1/install`.
  /// - **Subsequent Launches:** If an [installId] exists, it skips the network call
  ///   and returns the locally cached attribution data.
  /// - **Error Handling:** If the network call fails on the first launch, it
  ///   gracefully treats the install as "organic" (no attribution) so the SDK
  ///   remains functional. Re-attribution may be attempted on the next launch.
  ///
  /// Parameters:
  /// - [attributionWindowHours]: The lookback window in hours for matching clicks.
  /// - [deviceId]: An optional persistent device ID (like IDFA or GAID).
  /// - [appToken]: An optional public workspace token (LinkForty Cloud) so the
  ///   backend can scope attribution to the correct workspace.
  Future<InstallResponse> reportInstall({
    required int attributionWindowHours,
    String? deviceId,
    String? appToken,
  }) async {
    final storedInstallId = _storageManager.getInstallId();
    if (storedInstallId != null) {
      final cachedData = _storageManager.getInstallData();
      LinkFortyLogger.log(
        'Subsequent launch — loading cached attribution (installId: $storedInstallId)',
      );
      // Only the launch that reports the install receives the server's match
      // details; attributionMethod and competingLinks stay null (unknown) here.
      // The cached deep link keeps the values it was saved with.
      return InstallResponse(
        installId: storedInstallId,
        attributed: cachedData != null,
        confidenceScore: cachedData != null ? 100.0 : 0.0,
        matchedFactors: const [],
        deepLinkData: cachedData,
      );
    }

    final referrerRead = _readInstallReferrer?.call();
    final fingerprint = await _fingerprintCollector.collectFingerprint(
      attributionWindowHours: attributionWindowHours,
      deviceId: deviceId,
    );
    // On Android, the Play install referrer names the click exactly; without
    // one the install is matched by fingerprint.
    final installReferrer = await referrerRead;

    // Attach the workspace token (when provided) so Cloud can scope attribution
    // to the correct workspace rather than relying solely on fingerprint matching.
    final body = <String, dynamic>{
      ...fingerprint.toJson(),
      'appToken': ?appToken,
      'installReferrer': ?installReferrer,
    };

    LinkFortyLogger.log(
      'Reporting install with fingerprint: $fingerprint, install referrer: $installReferrer',
    );

    InstallResponse response;
    try {
      response = await _networkManager.request<InstallResponse>(
        endpoint: '/api/sdk/v1/install',
        method: HttpMethod.post,
        body: body,
        fromJson: (json) => InstallResponse.fromJson(json),
      );
      LinkFortyLogger.log('Install response: $response');
    } on LinkFortyError catch (e) {
      LinkFortyLogger.log(
        'Install network call failed — treating as organic. Error: $e',
      );
      return InstallResponse(
        installId: '',
        attributed: false,
        confidenceScore: 0.0,
        matchedFactors: const [],
      );
    }

    await _storageManager.saveInstallId(response.installId);

    final deepLinkData = response.deepLinkData;
    if (deepLinkData != null) {
      await _storageManager.saveInstallData(deepLinkData);
      LinkFortyLogger.log(
        'Install attributed with confidence: ${response.confidenceScore}%',
      );
    } else {
      LinkFortyLogger.log('Organic install (no attribution)');
    }

    await _storageManager.setHasLaunched();

    return response;
  }

  // MARK: - Data Retrieval

  /// Retrieves the install ID
  ///
  /// - Returns: Install ID if available, null otherwise
  String? getInstallId() {
    return _storageManager.getInstallId();
  }

  /// Retrieves the cached install attribution data
  ///
  /// - Returns: Deep link data if available, null otherwise
  DeepLinkData? getInstallData() {
    return _storageManager.getInstallData();
  }

  /// Checks if this is the first launch
  ///
  /// - Returns: True if first launch, false otherwise
  bool isFirstLaunch() {
    return _storageManager.isFirstLaunch();
  }

  // MARK: - Data Management

  /// Clears all cached attribution data
  Future<void> clearData() async {
    await _storageManager.clearAll();
    LinkFortyLogger.log('Attribution data cleared');
  }
}
