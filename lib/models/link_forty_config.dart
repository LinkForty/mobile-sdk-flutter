// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Holds all configuration settings required to initialize the LinkForty SDK.
class LinkFortyConfig {
  /// The base URL of your LinkForty instance.
  ///
  /// Must be HTTPS in production (HTTP allowed for localhost testing only).
  final Uri baseURL;

  /// API key for LinkForty Cloud (optional for self-hosted Core).
  ///
  /// Sent as Bearer token in Authorization header.
  final String? apiKey;

  /// Public workspace token (LinkForty Cloud).
  ///
  /// Sent with install events so the backend can scope attribution to the
  /// correct workspace instead of relying solely on fingerprint matching.
  /// Recommended for Cloud; shipped in the app bundle (attribution scoping,
  /// not a secret). Find it under Workspace Settings → App Token. Omit for
  /// self-hosted Core.
  final String? appToken;

  /// Enable debug logging.
  ///
  /// Logs network requests, responses, and SDK operations.
  final bool debug;

  /// Attribution window in hours (1-2160, default: 168 = 7 days).
  ///
  /// How long after a click an install can be attributed.
  final int attributionWindowHours;

  /// Creates a new LinkForty configuration.
  ///
  /// - [baseURL]: The base URL of your LinkForty instance (e.g., https://go.yourdomain.com).
  /// - [apiKey]: Optional API key for LinkForty Cloud authentication.
  /// - [appToken]: Optional public workspace token for LinkForty Cloud attribution scoping.
  /// - [debug]: Enable debug logging (default: false).
  /// - [attributionWindowHours]: Attribution window in hours (default: 168 = 7 days).
  ///
  /// For self-hosted LinkForty Core, omit the apiKey and appToken parameters.
  const LinkFortyConfig({
    required this.baseURL,
    this.apiKey,
    this.appToken,
    this.debug = false,
    this.attributionWindowHours = 168,
  });

  /// Validates the configuration.
  ///
  /// Throws [LinkFortyException] if validation fails.
  void validate() {
    // Validate HTTPS (except localhost)
    if (baseURL.scheme != 'https' && !_isLocalhost) {
      throw LinkFortyException.invalidConfiguration(
        'Base URL must use HTTPS (HTTP only allowed for localhost)',
      );
    }

    // Validate attribution window (1 hour to 90 days)
    if (attributionWindowHours < 1 || attributionWindowHours > 2160) {
      throw LinkFortyException.invalidConfiguration(
        'Attribution window must be between 1 and 2160 hours',
      );
    }
  }

  /// Checks if the base URL is localhost.
  bool get _isLocalhost {
    final host = baseURL.host;
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '10.0.2.2'; // Android emulator
  }

  @override
  String toString() {
    return '''LinkFortyConfig(
    baseURL: ${baseURL.toString()},
    apiKey: ${apiKey != null ? '***' : 'null'},
    appToken: ${appToken != null ? '***' : 'null'},
    debug: $debug,
    attributionWindowHours: $attributionWindowHours
)''';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkFortyConfig &&
          runtimeType == other.runtimeType &&
          baseURL == other.baseURL &&
          apiKey == other.apiKey &&
          appToken == other.appToken &&
          debug == other.debug &&
          attributionWindowHours == other.attributionWindowHours;

  @override
  int get hashCode =>
      baseURL.hashCode ^
      apiKey.hashCode ^
      appToken.hashCode ^
      debug.hashCode ^
      attributionWindowHours.hashCode;
}

/// LinkForty SDK exceptions.
class LinkFortyException implements Exception {
  final String message;
  final String? details;

  const LinkFortyException(this.message, [this.details]);

  /// Invalid configuration error.
  factory LinkFortyException.invalidConfiguration(String message) {
    return LinkFortyException('Invalid configuration: $message');
  }

  @override
  String toString() {
    if (details != null) {
      return 'LinkFortyException: $message\nDetails: $details';
    }
    return 'LinkFortyException: $message';
  }
}
