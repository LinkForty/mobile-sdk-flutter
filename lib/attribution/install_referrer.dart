// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../link_forty_logger.dart';

/// Reads the install referrer: null when there is none. Never throws.
typedef InstallReferrerReader = Future<String?> Function();

/// Reads the referrer Google Play recorded for this install, on Android.
///
/// A LinkForty link puts its click id in the referrer of every Play listing it
/// sends a visitor to, so the server can match the install to that click
/// exactly.
///
/// Returns null on other platforms, without Play (another store, a sideload),
/// when Play doesn't answer within [timeout], and on any error: the install is
/// then matched by fingerprint. A failed read is tried once more within
/// [timeout].
class PlayInstallReferrer {
  PlayInstallReferrer._();

  /// How long the install report waits for Play, retry included.
  static const Duration defaultTimeout = Duration(seconds: 2);

  static const Duration _retryDelay = Duration(milliseconds: 250);

  /// Reads the referrer. [query] and [isAndroid] are for tests.
  static Future<String?> read({
    Future<String?> Function()? query,
    bool? isAndroid,
    Duration timeout = defaultTimeout,
  }) async {
    final android = isAndroid ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    if (!android) return null;
    final ask = query ??
        () async =>
            (await AndroidPlayInstallReferrer.installReferrer).installReferrer;

    final deadline = DateTime.now().add(timeout);
    for (var attempt = 0; attempt < 2; attempt++) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      try {
        final value = await ask().timeout(remaining);
        return value != null && value.trim().isNotEmpty ? value : null;
      } on TimeoutException {
        LinkFortyLogger.log('Play install referrer: no answer in time');
        return null;
      } on MissingPluginException {
        LinkFortyLogger.log('Play install referrer: plugin not available');
        return null;
      } catch (e) {
        LinkFortyLogger.log('Play install referrer unavailable: $e');
        if (attempt == 0) {
          final left = deadline.difference(DateTime.now());
          await Future<void>.delayed(left < _retryDelay ? left : _retryDelay);
        }
      }
    }
    return null;
  }
}
