// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import '../attribution/attribution_context.dart';
import '../link_forty_logger.dart';
import '../models/deep_link_data.dart';
import '../network/network_manager.dart';
import '../network/http_method.dart';
import '../fingerprint/fingerprint_collector.dart';
import '../utilities/url_parser.dart';

/// Callback for deferred deep links (install attribution)
///
/// Parameter: Deep link data if attributed, null for organic installs
typedef DeferredDeepLinkCallback = void Function(DeepLinkData? deepLinkData);

/// Callback for direct deep links (App Links, custom schemes)
///
/// Parameters:
/// - [uri]: The URI that opened the app
/// - [deepLinkData]: Parsed deep link data, null if parsing failed
typedef DeepLinkCallback = void Function(Uri uri, DeepLinkData? deepLinkData);

/// Responsible for handling both deferred and direct deep links.
///
/// This class manages the registration of callbacks and performs server-side
/// resolution of deep link URLs to extract campaign metadata.
class DeepLinkHandler {
  final List<DeferredDeepLinkCallback> _deferredDeepLinkCallbacks = [];
  final List<DeepLinkCallback> _deepLinkCallbacks = [];

  /// Network manager for server-side URL resolution
  NetworkManagerProtocol? _networkManager;

  /// Fingerprint collector for resolution requests
  FingerprintCollectorProtocol? _fingerprintCollector;

  /// Last-click attribution context updated on each deep-link open
  AttributionContext? _attributionContext;

  /// Flag to track if deferred deep link has been delivered
  bool _deferredDeepLinkDelivered = false;

  /// Cached deferred deep link data
  DeepLinkData? _cachedDeferredDeepLink;

  // MARK: - Configuration

  /// Configures the handler with the necessary components for server-side
  /// URL resolution.
  ///
  /// Parameters:
  /// - [networkManager]: The network layer for API requests.
  /// - [fingerprintCollector]: The collector for device metadata.
  /// - [baseURL]: The base URL used for identifying LinkForty-shortened links.
  void configure({
    required NetworkManagerProtocol networkManager,
    required FingerprintCollectorProtocol fingerprintCollector,
    required Uri baseURL,
    AttributionContext? attributionContext,
  }) {
    _networkManager = networkManager;
    _fingerprintCollector = fingerprintCollector;
    _attributionContext = attributionContext;
  }

  // MARK: - Deferred Deep Link (Install Attribution)

  /// Registers a [callback] for deferred deep links.
  ///
  /// Deferred links are those that were clicked before the app was installed.
  /// If data is already available from a previous attribution call, the
  /// callback is invoked immediately in a microtask.
  void onDeferredDeepLink(DeferredDeepLinkCallback callback) {
    _deferredDeepLinkCallbacks.add(callback);

    if (_deferredDeepLinkDelivered) {
      Future.microtask(() => callback(_cachedDeferredDeepLink));
    }
  }

  /// Delivers deferred deep link data to all registered callbacks
  ///
  /// - [deepLinkData]: Deep link data from attribution, null for organic
  Future<void> deliverDeferredDeepLink(DeepLinkData? deepLinkData) async {
    _cachedDeferredDeepLink = deepLinkData;
    _deferredDeepLinkDelivered = true;

    // Pin last-click attribution to this deferred (install) open.
    await _attributionContext?.recordDeepLinkOpen(linkId: deepLinkData?.linkId);

    LinkFortyLogger.log(
      'Delivering deferred deep link: ${deepLinkData?.shortCode ?? "organic"}',
    );

    // Create a snapshot of callbacks to avoid modification during iteration
    final callbacks = List<DeferredDeepLinkCallback>.from(
      _deferredDeepLinkCallbacks,
    );

    // Invoke all callbacks
    for (final callback in callbacks) {
      callback(deepLinkData);
    }
  }

  // MARK: - Direct Deep Link (App Links, Custom Schemes)

  /// Registers a callback for direct deep links
  ///
  /// - [callback]: Callback to invoke when app is opened via deep link
  void onDeepLink(DeepLinkCallback callback) {
    _deepLinkCallbacks.add(callback);
  }

  /// Resolves the provided [uri] to extract [DeepLinkData].
  ///
  /// It first attempts to resolve the URL via the LinkForty backend to get
  /// full campaign metadata. If the network request fails or the SDK is not
  /// configured for server-side resolution, it falls back to parsing the URL locally.
  Future<void> handleDeepLink(Uri uri) async {
    LinkFortyLogger.log('Handling deep link: $uri');

    final localData = URLParser.parseDeepLink(uri);

    final resolvedData =
        (_networkManager != null && _fingerprintCollector != null)
            ? await _resolveUrl(uri, fallback: localData)
            : localData;

    final callbacks = List<DeepLinkCallback>.from(_deepLinkCallbacks);

    if (resolvedData != null) {
      // Pin last-click attribution to this direct (re-engagement) open;
      // supersedes any prior context. Organic/unresolved opens are a no-op.
      await _attributionContext?.recordDeepLinkOpen(
        linkId: resolvedData.linkId,
      );
      LinkFortyLogger.log('Parsed deep link: $resolvedData');
    } else {
      LinkFortyLogger.log('Failed to parse deep link URL');
    }

    for (final callback in callbacks) {
      callback(uri, resolvedData);
    }
  }

  // MARK: - Testing Helpers

  /// Clears all registered callbacks (for testing / reset)
  void clearCallbacks() {
    _deferredDeepLinkCallbacks.clear();
    _deepLinkCallbacks.clear();
    _deferredDeepLinkDelivered = false;
    _cachedDeferredDeepLink = null;
  }

  // MARK: - Private Methods

  /// Resolves a URL via the server, falling back to local data on failure
  Future<DeepLinkData?> _resolveUrl(Uri uri, {DeepLinkData? fallback}) async {
    final networkManager = _networkManager;
    final fingerprintCollector = _fingerprintCollector;

    if (networkManager == null || fingerprintCollector == null) {
      return fallback;
    }

    // Extract path segments
    final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (pathSegments.isEmpty) return fallback;

    // Build resolve path: /api/sdk/v1/resolve/{templateSlug?}/{shortCode}
    final String resolvePath;
    if (pathSegments.length >= 2) {
      final templateSlug = pathSegments[pathSegments.length - 2];
      final shortCode = pathSegments[pathSegments.length - 1];
      resolvePath = '/api/sdk/v1/resolve/$templateSlug/$shortCode';
    } else {
      final shortCode = pathSegments[0];
      resolvePath = '/api/sdk/v1/resolve/$shortCode';
    }

    // Collect fingerprint for query parameters
    final fingerprint = await fingerprintCollector.collectFingerprint(
      attributionWindowHours: 168,
      deviceId: null,
    );

    // Build query parameters
    final queryParams = {
      'fp_tz': fingerprint.timezone,
      'fp_lang': fingerprint.language,
      'fp_sw': fingerprint.screenWidth.toString(),
      'fp_sh': fingerprint.screenHeight.toString(),
      'fp_platform': fingerprint.platform,
      'fp_pv': fingerprint.platformVersion,
    };

    // Build query string
    final queryString = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final endpoint = '$resolvePath?$queryString';

    try {
      final resolved = await networkManager.request<DeepLinkData>(
        endpoint: endpoint,
        method: HttpMethod.get,
        fromJson: (json) => DeepLinkData.fromJson(json),
      );

      LinkFortyLogger.log('Server-side resolution succeeded for $uri');
      return resolved;
    } catch (e) {
      LinkFortyLogger.log(
        'Server-side resolution failed, using local parse: $e',
      );
      return fallback;
    }
  }
}
