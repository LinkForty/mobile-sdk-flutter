// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Identifies this SDK (name + version) on outbound requests so the backend can
/// report which SDKs/versions are in use and flag outdated integrations.
///
/// **Important:** [version] is hardcoded because Dart exposes no reliable
/// runtime version for the package itself. Bump it together with the `version:`
/// field in `pubspec.yaml` and the CHANGELOG entry so the reported version stays
/// accurate.
class SdkInfo {
  const SdkInfo._();

  /// SDK platform identifier, sent as `sdkName` (and in the `X-LinkForty-SDK` header).
  static const String name = 'flutter';

  /// SDK release version, sent as `sdkVersion`. Keep in sync with pubspec.yaml.
  static const String version = '0.2.0';
}
