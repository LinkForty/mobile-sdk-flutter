// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'link_forty_logger.dart';
import 'models/link_forty_config.dart';
import 'models/install_response.dart';
import 'models/deep_link_data.dart';
import 'models/create_link_options.dart';
import 'models/create_link_result.dart';
import 'models/dashboard_create_link_response.dart';
import 'network/network_manager.dart';
import 'network/http_method.dart';
import 'storage/storage_manager.dart';
import 'fingerprint/fingerprint_collector.dart';
import 'attribution/attribution_manager.dart';
import 'events/event_tracker.dart';
import 'deeplink/deeplink_handler.dart';
import 'errors/link_forty_error.dart';

/// The entry point for the LinkForty SDK.
///
/// Use [LinkForty.instance] to access SDK features like event tracking,
/// link creation, and attribution data.
///
/// Example initialization:
/// ```dart
/// final config = LinkFortyConfig(
///   baseURL: Uri.parse('https://go.yourdomain.com'),
///   apiKey: 'your-api-key',
/// );
/// final response = await LinkForty.initialize(config: config);
/// ```
class LinkForty {
  // MARK: - Singleton

  static LinkForty? _instance;

  /// Returns the shared instance of [LinkForty].
  ///
  /// Throws [NotInitializedError] if the SDK has not been initialized.
  static LinkForty get instance {
    final inst = _instance;
    if (inst == null) {
      throw const NotInitializedError();
    }
    return inst;
  }

  /// Returns the shared instance of [LinkForty], or `null` if not initialized.
  static LinkForty? get instanceOrNull => _instance;

  // MARK: - Properties

  LinkFortyConfig? _config;
  NetworkManagerProtocol? _networkManager;
  AttributionManager? _attributionManager;
  EventTracker? _eventTracker;
  DeepLinkHandler? _deepLinkHandler;

  final Completer<void> _initializationCompleter = Completer<void>();
  bool _isInitialized = false;

  // Private constructor
  LinkForty._();

  // MARK: - Initialization

  /// Initializes the LinkForty SDK with the provided [config].
  ///
  /// This must be called before using any other SDK features.
  ///
  /// Parameters:
  /// - [config]: The SDK configuration object.
  /// - [attributionWindowHours]: The duration in hours to look back for clicks.
  ///   Defaults to 168 hours (7 days).
  /// - [deviceId]: An optional unique device identifier for high-confidence matching.
  /// - [networkManager]: For testing - allows injecting a mock network layer.
  /// - [storageManager]: For testing - allows injecting a mock storage layer.
  /// - [fingerprintCollector]: For testing - allows injecting a mock collector.
  ///
  /// Returns an [InstallResponse] containing attribution results.
  ///
  /// Throws [AlreadyInitializedError] if called more than once without [reset].
  /// Throws [LinkFortyError] if initialization or initial attribution fails.
  static Future<InstallResponse> initialize({
    required LinkFortyConfig config,
    int attributionWindowHours = 168,
    String? deviceId,
    @visibleForTesting NetworkManagerProtocol? networkManager,
    @visibleForTesting StorageManagerProtocol? storageManager,
    @visibleForTesting FingerprintCollectorProtocol? fingerprintCollector,
  }) async {
    if (_instance != null) {
      throw const AlreadyInitializedError();
    }

    config.validate();

    final sdk = LinkForty._();
    sdk._config = config;

    LinkFortyLogger.isDebugEnabled = config.debug;

    final effectiveStorageManager =
        storageManager ?? await StorageManager.create();
    final effectiveNetworkManager =
        networkManager ?? NetworkManager(config: config);
    final effectiveFingerprintCollector =
        fingerprintCollector ?? FingerprintCollector();

    sdk._networkManager = effectiveNetworkManager;

    sdk._attributionManager = AttributionManager(
      networkManager: effectiveNetworkManager,
      storageManager: effectiveStorageManager,
      fingerprintCollector: effectiveFingerprintCollector,
    );

    sdk._eventTracker = EventTracker(
      networkManager: effectiveNetworkManager,
      storageManager: effectiveStorageManager,
    );

    final deepLinkHandler = DeepLinkHandler();
    deepLinkHandler.configure(
      networkManager: effectiveNetworkManager,
      fingerprintCollector: effectiveFingerprintCollector,
      baseURL: config.baseURL,
    );
    sdk._deepLinkHandler = deepLinkHandler;

    sdk._isInitialized = true;
    _instance = sdk;
    sdk._initializationCompleter.complete();

    final response = await sdk._attributionManager!.reportInstall(
      attributionWindowHours: attributionWindowHours,
      deviceId: deviceId,
      appToken: config.appToken,
    );

    if (response.attributed && response.deepLinkData != null) {
      await sdk._deepLinkHandler?.deliverDeferredDeepLink(
        response.deepLinkData,
      );
    }

    LinkFortyLogger.log(
      'SDK initialized successfully (attributed: ${response.attributed})',
    );

    return response;
  }

  // MARK: - Deep Linking

  /// Processes a deep link [uri] manually.
  ///
  /// Use this if you are handling incoming links via your own platform channel
  /// instead of the SDK's built-in automatic handling.
  Future<void> handleDeepLink(Uri uri) async {
    if (!_isInitialized) {
      LinkFortyLogger.log('SDK not initialized. Call initialize() first.');
      return;
    }
    await _deepLinkHandler?.handleDeepLink(uri);
  }

  /// Sets a [callback] to be invoked when a deferred deep link is resolved.
  ///
  /// Deferred links are those clicked before the app was installed.
  void onDeferredDeepLink(DeferredDeepLinkCallback callback) {
    if (!_isInitialized) {
      LinkFortyLogger.log('SDK not initialized. Call initialize() first.');
      return;
    }
    _deepLinkHandler?.onDeferredDeepLink(callback);
  }

  /// Sets a [callback] to be invoked when a direct deep link is opened.
  ///
  /// Direct links are those clicked while the app is already installed.
  void onDeepLink(DeepLinkCallback callback) {
    if (!_isInitialized) {
      LinkFortyLogger.log('SDK not initialized. Call initialize() first.');
      return;
    }
    _deepLinkHandler?.onDeepLink(callback);
  }

  // MARK: - Event Tracking

  /// Tracks a custom in-app event with the given [name].
  ///
  /// You can optionally provide a [properties] map containing additional
  /// context for the event. Values must be JSON-serializable.
  ///
  /// Throws [NotInitializedError] if the SDK is not initialized.
  Future<void> trackEvent(
    String name, [
    Map<String, dynamic>? properties,
  ]) async {
    if (!_isInitialized) {
      throw const NotInitializedError();
    }
    await _eventTracker?.trackEvent(name, properties);
  }

  /// Tracks a revenue-generating event.
  ///
  /// Parameters:
  /// - [amount]: The decimal value of the transaction (e.g., 9.99).
  /// - [currency]: The 3-letter ISO 4217 currency code (e.g., "USD").
  /// - [properties]: Optional additional metadata about the purchase.
  ///
  /// Throws [NotInitializedError] if the SDK is not initialized.
  Future<void> trackRevenue({
    required double amount,
    required String currency,
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized) {
      throw const NotInitializedError();
    }
    await _eventTracker?.trackRevenue(
      amount: amount,
      currency: currency,
      properties: properties,
    );
  }

  /// Manually triggers a flush of all queued events to the server.
  ///
  /// The SDK automatically flushes events, but this can be used to ensure
  /// events are sent before app termination or in response to a network change.
  Future<void> flushEvents() async {
    if (!_isInitialized) {
      LinkFortyLogger.log('SDK not initialized. Call initialize() first.');
      return;
    }
    await _eventTracker?.flushQueue();
  }

  /// Returns the number of events currently waiting in the offline queue.
  int get queuedEventCount {
    if (!_isInitialized) return 0;
    return _eventTracker?.queuedEventCount ?? 0;
  }

  /// Discards all events currently in the offline queue without sending them.
  void clearEventQueue() {
    if (!_isInitialized) {
      LinkFortyLogger.log('SDK not initialized. Call initialize() first.');
      return;
    }
    _eventTracker?.clearQueue();
  }

  // MARK: - Link Creation

  /// Creates a new short link programmatically based on the provided [options].
  ///
  /// This feature requires an [apiKey] to be configured in the [LinkFortyConfig].
  /// As per the specification, a [CreateLinkOptions.templateId] is mandatory.
  ///
  /// Returns a [CreateLinkResult] containing the generated URL and metadata.
  ///
  /// Throws [NotInitializedError] if the SDK is not initialized.
  /// Throws [MissingApiKeyError] if no API key is available.
  /// Throws [MissingTemplateIdError] if no template ID is provided in options.
  Future<CreateLinkResult> createLink(CreateLinkOptions options) async {
    if (!_isInitialized) {
      throw const NotInitializedError();
    }

    final config = _config;
    if (config == null) {
      throw const NotInitializedError();
    }

    if (config.apiKey == null) {
      throw const MissingApiKeyError();
    }

    if (options.templateId == null) {
      throw const MissingTemplateIdError();
    }

    final networkManager = _networkManager;
    if (networkManager == null) {
      throw const NotInitializedError();
    }

    final response = await networkManager.request<DashboardCreateLinkResponse>(
      endpoint: '/api/links',
      method: HttpMethod.post,
      body: options.toJson(),
      fromJson: (json) => DashboardCreateLinkResponse.fromJson(json),
    );

    final baseUrl = config.baseURL.toString().replaceAll(RegExp(r'/$'), '');
    final templateSlug = options.templateSlug ?? '';
    final pathSegment = templateSlug.isEmpty
        ? response.shortCode
        : '$templateSlug/${response.shortCode}';
    final url = '$baseUrl/$pathSegment';

    return CreateLinkResult(
      url: url,
      shortCode: response.shortCode,
      linkId: response.id,
    );
  }

  // MARK: - Attribution Data

  /// Returns the unique [installId] assigned to this device by the backend.
  ///
  /// Returns `null` if the SDK is not initialized or no ID has been assigned.
  String? getInstallId() {
    if (!_isInitialized) return null;
    return _attributionManager?.getInstallId();
  }

  /// Returns the [DeepLinkData] associated with the initial install attribution.
  ///
  /// Returns `null` if the SDK is not initialized or the install was organic.
  DeepLinkData? getInstallData() {
    if (!_isInitialized) return null;
    return _attributionManager?.getInstallData();
  }

  /// Returns whether this app session is considered a first launch.
  ///
  /// First launch refers to the very first time the app is opened after installation,
  /// before any attribution reporting has completed.
  bool isFirstLaunch() {
    if (!_isInitialized) return true;
    return _attributionManager?.isFirstLaunch() ?? true;
  }

  /// Permanently removes all SDK-related data from local storage.
  ///
  /// This includes the install ID, cached attribution data, and any queued events.
  /// Use this for user privacy compliance (e.g., GDPR/CCPA).
  Future<void> clearData() async {
    await _attributionManager?.clearData();
    _eventTracker?.clearQueue();
    _deepLinkHandler?.clearCallbacks();
    LinkFortyLogger.log('All SDK data cleared');
  }

  /// Resets the SDK singleton to an uninitialized state.
  ///
  /// This is primarily used for testing or re-configuring the SDK.
  /// It does **not** clear persistent data from storage; call [clearData] for that.
  void reset() {
    _config = null;
    _networkManager = null;
    _attributionManager = null;
    _eventTracker = null;
    _deepLinkHandler = null;
    _isInitialized = false;
    _instance = null;
    LinkFortyLogger.log('SDK reset to uninitialized state');
  }
}
