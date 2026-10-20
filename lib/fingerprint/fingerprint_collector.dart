// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'device_fingerprint.dart';

class _ScreenDimensions {
  final int width;
  final int height;
  _ScreenDimensions(this.width, this.height);
}

class _PlatformInfo {
  final String name;
  final String version;
  _PlatformInfo(this.name, this.version);
}

/// Protocol for [FingerprintCollector] to enable dependency injection in tests.
abstract class FingerprintCollectorProtocol {
  /// Collects a snapshot of device properties for attribution matching.
  Future<DeviceFingerprint> collectFingerprint({
    required int attributionWindowHours,
    String? deviceId,
  });
}

/// Responsible for gathering device and environment data used for
/// probabilistic attribution matching.
class FingerprintCollector implements FingerprintCollectorProtocol {
  final DeviceInfoPlugin _deviceInfo;
  final PackageInfo? _packageInfo;

  /// Creates a fingerprint collector
  ///
  /// - [deviceInfo]: Device info plugin instance
  /// - [packageInfo]: Package info (if already loaded)
  FingerprintCollector({DeviceInfoPlugin? deviceInfo, PackageInfo? packageInfo})
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _packageInfo = packageInfo;

  /// Collects a [DeviceFingerprint] containing properties like screen size,
  /// timezone, language, and platform version.
  ///
  /// Parameters:
  /// - [attributionWindowHours]: The duration to look back for clicks.
  /// - [deviceId]: An optional persistent device identifier (e.g., IDFA).
  @override
  Future<DeviceFingerprint> collectFingerprint({
    required int attributionWindowHours,
    String? deviceId,
  }) async {
    final packageInfo = _packageInfo ?? await PackageInfo.fromPlatform();
    final dims = _getScreenDimensions();
    final screenWidth = dims.width;
    final screenHeight = dims.height;
    final userAgent = await _generateUserAgent(packageInfo);
    final info = await _getPlatformInfo();
    final platform = info.name;
    final platformVersion = info.version;

    return DeviceFingerprint(
      userAgent: userAgent,
      timezone: _getTimezone(),
      language: _getLanguage(),
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      platform: platform,
      platformVersion: platformVersion,
      appVersion: packageInfo.version,
      deviceId: deviceId,
      attributionWindowHours: attributionWindowHours,
    );
  }

  // MARK: - Private Helpers

  /// Generates a User-Agent string
  ///
  /// Format: "AppName/AppVersion Platform/PlatformVersion"
  Future<String> _generateUserAgent(PackageInfo packageInfo) async {
    final appName = packageInfo.appName;
    final appVersion = packageInfo.version;
    final info = await _getPlatformInfo();
    final platform = info.name;
    final platformVersion = info.version;

    return '$appName/$appVersion $platform/$platformVersion';
  }

  /// Returns screen dimensions in native pixels
  _ScreenDimensions _getScreenDimensions() {
    try {
      // Ensure bindings are initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Get the first view from the platform dispatcher
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isEmpty) {
        return _ScreenDimensions(0, 0);
      }

      final view = views.first;
      final physicalSize = view.physicalSize;

      return _ScreenDimensions(
        physicalSize.width.toInt(),
        physicalSize.height.toInt(),
      );
    } catch (e) {
      // Fallback for testing or headless environments
      return _ScreenDimensions(0, 0);
    }
  }

  /// Gets timezone identifier (e.g., "America/New_York")
  String _getTimezone() {
    try {
      // Try to get the location timezone
      final location = tz.local;
      return location.name;
    } catch (_) {
      // Fallback to simple timezone name
      return DateTime.now().timeZoneName;
    }
  }

  /// Gets language identifier (e.g., "en-US")
  String _getLanguage() => languageTag(ui.PlatformDispatcher.instance.locale);

  /// The language reported in the fingerprint: `language` or
  /// `language-REGION` (`en-ES`, `zh-CN`, `es-419`).
  ///
  /// The engine delivers the device locale already split into language,
  /// script and country, without the platform's extensions (Android's
  /// `-u-fw-mon-mu-celsius`, iOS's `@rg=` keywords). The script is left out
  /// so the value matches what a browser on the same device reports.
  @visibleForTesting
  static String languageTag(ui.Locale locale) {
    final countryCode = locale.countryCode;
    if (countryCode != null && countryCode.isNotEmpty) {
      return '${locale.languageCode}-$countryCode';
    }
    return locale.languageCode;
  }

  /// Gets platform and version information
  Future<_PlatformInfo> _getPlatformInfo() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return _PlatformInfo('Android', androidInfo.version.release);
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return _PlatformInfo('iOS', iosInfo.systemVersion);
    } else if (Platform.isMacOS) {
      final macosInfo = await _deviceInfo.macOsInfo;
      return _PlatformInfo('macOS', macosInfo.osRelease);
    } else if (Platform.isWindows) {
      final windowsInfo = await _deviceInfo.windowsInfo;
      return _PlatformInfo('Windows', windowsInfo.buildNumber.toString());
    } else if (Platform.isLinux) {
      final linuxInfo = await _deviceInfo.linuxInfo;
      return _PlatformInfo('Linux', linuxInfo.version ?? 'Unknown');
    } else {
      return _PlatformInfo(Platform.operatingSystem, 'Unknown');
    }
  }
}
