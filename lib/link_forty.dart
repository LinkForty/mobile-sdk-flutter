// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:app_links/app_links.dart';
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
import 'attribution/attribution_context.dart';
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
  AttributionContext? _attributionContext;
  EventTracker? _eventTracker;
  DeepLinkHandler? _deepLinkHandler;
  StreamSubscription<Uri>? _incomingLinkSubscription;

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
  ///   Overrides [LinkFortyConfig.attributionWindowHours] when given.
  /// - [deviceId]: An optional unique device identifier for high-confidence matching.
  /// - [networkManager]: For testing - allows injecting a mock network layer.
  /// - [storageManager]: For testing - allows injecting a mock storage layer.
  /// - [fingerprintCollector]: For testing - allows injecting a mock collector.
  /// - [incomingLinks]: For testing - replaces the platform's stream of
  ///   incoming App Links / Universal Links / custom-scheme URLs.
  ///
  /// The SDK starts listening for incoming links here, including the link
  /// that launched the app, and passes each one to [onDeepLink] callbacks. A
  /// link that arrives before any callback is registered is held and
  /// delivered to the first one, so registering after `initialize()` returns
  /// is fine.
  ///
  /// Once the install has been reported, [onDeferredDeepLink] callbacks
  /// receive its attribution data, or `null` for an organic install.
  ///
  /// Returns an [InstallResponse] containing attribution results.
  ///
  /// Throws [AlreadyInitializedError] if called more than once without [reset].
  /// Throws [LinkFortyError] if initialization or initial attribution fails.
  static Future<InstallResponse> initialize({
    required LinkFortyConfig config,
    int? attributionWindowHours,
    String? deviceId,
    @visibleForTesting NetworkManagerProtocol? networkManager,
    @visibleForTesting StorageManagerProtocol? storageManager,
    @visibleForTesting FingerprintCollectorProtocol? fingerprintCollector,
    @visibleForTesting Stream<Uri>? incomingLinks,
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

    final attributionContext = AttributionContext(
      storage: effectiveStorageManager,
      debug: config.debug,
    );
    sdk._attributionContext = attributionContext;

    sdk._attributionManager = AttributionManager(
      networkManager: effectiveNetworkManager,
      storageManager: effectiveStorageManager,
      fingerprintCollector: effectiveFingerprintCollector,
    );

    sdk._eventTracker = EventTracker(
      networkManager: effectiveNetworkManager,
      storageManager: effectiveStorageManager,
      attributionContext: attributionContext,
    );

    final deepLinkHandler = DeepLinkHandler();
    deepLinkHandler.configure(
      networkManager: effectiveNetworkManager,
      fingerprintCollector: effectiveFingerprintCollector,
      baseURL: config.baseURL,
      attributionContext: attributionContext,
    );
    sdk._deepLinkHandler = deepLinkHandler;

    sdk._isInitialized = true;
    _instance = sdk;
    sdk._initializationCompleter.complete();

    sdk._listenForIncomingLinks(incomingLinks ?? AppLinks().uriLinkStream);

    final isNewInstall = effectiveStorageManager.getInstallId() == null;
    final response = await sdk._attributionManager!.reportInstall(
      attributionWindowHours:
          attributionWindowHours ?? config.attributionWindowHours,
      deviceId: deviceId,
      appToken: config.appToken,
    );

    await sdk._deepLinkHandler?.deliverDeferredDeepLink(
      response.attributed ? response.deepLinkData : null,
      isNewInstall: isNewInstall,
    );

    LinkFortyLogger.log(
      'SDK initialized successfully (attributed: ${response.attributed})',
    );

    return response;
  }

  // MARK: - Deep Linking

  /// Passes each incoming link to the deep link handler.
  ///
  /// The stream emits the link that launched the app as well as links opened
  /// while it runs. A platform without link support only loses direct deep
  /// links, so a failure here is logged rather than thrown.
  void _listenForIncomingLinks(Stream<Uri> links) {
    try {
      _incomingLinkSubscription = links.listen(
        (uri) {
          _deepLinkHandler?.handleDeepLink(uri).catchError((Object e) {
            LinkFortyLogger.log('Failed to handle incoming link $uri: $e');
          });
        },
        onError: (Object e) {
          LinkFortyLogger.log('Incoming link stream error: $e');
        },
      );
    } catch (e) {
      LinkFortyLogger.log('Could not listen for incoming links: $e');
    }
  }

  /// Processes a deep link [uri] manually.
  ///
  /// The SDK already handles incoming App Links, Universal Links and
  /// custom-scheme URLs. Use this for a link that reaches the app some other
  /// way, such as a push notification payload. The same URL handled twice in
  /// quick succession is delivered once.
  Future<void> handleDeepLink(Uri uri) async {
    if (!_isInitialized) {
      LinkFortyLogger.log('SDK not initialized. Call initialize() first.');
      return;
    }
    await _deepLinkHandler?.handleDeepLink(uri);
  }

  /// Sets a [callback] to be invoked with the install's attribution.
  ///
  /// Deferred links are those clicked before the app was installed. The
  /// callback receives the link's data, or `null` for an organic install. It
  /// is called once, on the launch that reports the install; a callback
  /// registered after [initialize] returns on that launch is called
  /// immediately. Later launches don't call it; the attribution stays
  /// available from [getInstallData].
  void onDeferredDeepLink(DeferredDeepLinkCallback callback) {
    if (!_isInitialized) {
      LinkFortyLogger.log('SDK not initialized. Call initialize() first.');
      return;
    }
    _deepLinkHandler?.onDeferredDeepLink(callback);
  }

  /// Sets a [callback] to be invoked when a direct deep link is opened.
  ///
  /// Direct links are those clicked while the app is already installed. The
  /// link that launched the app is delivered too, even when the callback is
  /// registered after [initialize] returns.
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

  /// Tracks a screen view for per-link screen-flow funnels.
  ///
  /// Emits a `screen_view` event stamped with the active last-click attribution
  /// context, so the dashboard can show which screens users reach after opening a
  /// deep link. For automatic tracking, add [LinkFortyNavigatorObserver] to your
  /// app's `navigatorObservers`.
  ///
  /// Throws [NotInitializedError] if the SDK is not initialized.
  Future<void> trackScreenView(
    String name, [
    Map<String, dynamic>? properties,
  ]) async {
    if (!_isInitialized) {
      throw const NotInitializedError();
    }
    await _eventTracker?.trackScreenView(name, properties);
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
    await _attributionContext?.clear();
    _eventTracker?.clearQueue();
    _deepLinkHandler?.clearCallbacks();
    LinkFortyLogger.log('All SDK data cleared');
  }

  /// Resets the SDK singleton to an uninitialized state.
  ///
  /// This is primarily used for testing or re-configuring the SDK.
  /// It does **not** clear persistent data from storage; call [clearData] for that.
  void reset() {
    final subscription = _incomingLinkSubscription;
    _incomingLinkSubscription = null;
    if (subscription != null) {
      try {
        unawaited(
          subscription.cancel().catchError((Object e) {
            LinkFortyLogger.log('Failed to stop listening for links: $e');
          }),
        );
      } catch (e) {
        LinkFortyLogger.log('Failed to stop listening for links: $e');
      }
    }
    _config = null;
    _networkManager = null;
    _attributionManager = null;
    _attributionContext = null;
    _eventTracker = null;
    _deepLinkHandler = null;
    _isInitialized = false;
    _instance = null;
    LinkFortyLogger.log('SDK reset to uninitialized state');
  }
}
