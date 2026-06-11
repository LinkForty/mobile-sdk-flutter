// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// SharedPreferences/Storage keys used by the SDK
class StorageKeys {
  // Private constructor to prevent instantiation
  const StorageKeys._();

  /// Prefix for all LinkForty SDK keys
  static const String _prefix = 'com.linkforty.sdk';

  /// SharedPreferences file name (Android-specific, not used in Flutter)
  static const String prefsName = '$_prefix.prefs';

  /// Install ID key
  static const String installId = '$_prefix.installId';

  /// Install data key (DeepLinkData JSON)
  static const String installData = '$_prefix.installData';

  /// First launch flag key
  static const String firstLaunch = '$_prefix.firstLaunch';

  /// Event queue key (JSON array of EventRequest)
  static const String eventQueue = '$_prefix.eventQueue';

  /// Active last-click attribution context key (ActiveAttribution JSON)
  static const String attribution = '$_prefix.attribution';
}
