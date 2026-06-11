// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';

import '../link_forty_logger.dart';
import '../storage/storage_manager.dart';

/// The active last-click attribution: the deep link currently credited for
/// in-app activity, and when it opened the app.
class ActiveAttribution {
  final String linkId;
  final String? clickId;

  /// ISO 8601 timestamp of when the deep link opened the app.
  final String openedAt;

  const ActiveAttribution({
    required this.linkId,
    this.clickId,
    required this.openedAt,
  });

  Map<String, dynamic> toJson() => {
        'linkId': linkId,
        if (clickId != null) 'clickId': clickId,
        'openedAt': openedAt,
      };

  factory ActiveAttribution.fromJson(Map<String, dynamic> json) =>
      ActiveAttribution(
        linkId: json['linkId'] as String,
        clickId: json['clickId'] as String?,
        openedAt: json['openedAt'] as String,
      );
}

/// The attribution fields merged into every event payload. [sessionId] is always
/// present; the link fields are absent until a deep link has opened the app.
class AttributionStamp {
  final String? attributedLinkId;
  final String? attributedClickId;
  final String? linkOpenedAt;
  final String sessionId;

  const AttributionStamp({
    this.attributedLinkId,
    this.attributedClickId,
    this.linkOpenedAt,
    required this.sessionId,
  });
}

/// Last-click attribution + session tracking for in-app events.
///
/// LinkForty attributes in-app activity (events and screen views) to the deep
/// link that drove it, using a last-click + window model:
///
/// - Every deep-link open (deferred install OR direct re-engagement) pins an
///   active context to THAT link. The newest open wins (supersede).
/// - Every event is stamped with the active context so the backend can credit
///   the link. The conversion window and session grouping are applied
///   server-side at query time — the SDK only reports the active link, when it
///   opened, and the current session.
/// - A [sessionId] identifies one app-open journey: generated on cold start and
///   rotated on each new deep-link open.
///
/// The active context is persisted so a reopen without a new click still
/// attributes to the last link. The session is in-memory: a cold start is a new
/// session.
class AttributionContext {
  final StorageManagerProtocol _storage;
  final bool _debug;

  ActiveAttribution? _active;
  String _sessionId;

  AttributionContext({
    required StorageManagerProtocol storage,
    bool debug = false,
  })  : _storage = storage,
        _debug = debug,
        _sessionId = _generateSessionId() {
    _active = _loadActive();
  }

  /// Records a deep-link open. The newest open supersedes the previous one
  /// (last-click) and starts a new session. A no-op when no [linkId] is known
  /// (organic/unresolved open) — there is nothing to attribute to.
  Future<void> recordDeepLinkOpen({String? linkId, String? clickId}) async {
    if (linkId == null) return;

    final attribution = ActiveAttribution(
      linkId: linkId,
      clickId: clickId,
      openedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _active = attribution;
    // A new deep-link open is the start of a new attributed journey.
    _sessionId = _generateSessionId();

    try {
      await _storage.saveAttribution(jsonEncode(attribution.toJson()));
    } catch (e) {
      if (_debug) LinkFortyLogger.log('Failed to persist attribution: $e');
    }

    if (_debug) {
      LinkFortyLogger.log(
        'Attribution context set: link=$linkId session=$_sessionId',
      );
    }
  }

  /// The attribution fields to merge into every event payload.
  AttributionStamp getStamp() => AttributionStamp(
        attributedLinkId: _active?.linkId,
        attributedClickId: _active?.clickId,
        linkOpenedAt: _active?.openedAt,
        sessionId: _sessionId,
      );

  /// The current session id (one app-open journey).
  String get sessionId => _sessionId;

  /// Clears the persisted context and starts a fresh session (used by clearData).
  Future<void> clear() async {
    _active = null;
    _sessionId = _generateSessionId();
    try {
      await _storage.removeAttribution();
    } catch (_) {
      // best-effort
    }
  }

  ActiveAttribution? _loadActive() {
    try {
      final raw = _storage.getAttribution();
      if (raw == null) return null;
      return ActiveAttribution.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Missing/corrupt data (or an unstubbed mock in tests) → no active context.
      return null;
    }
  }

  /// Generates an RFC4122-v4-style identifier for session grouping. Not a
  /// security token — `Random` is sufficient and avoids a native crypto dep.
  static String _generateSessionId() {
    final rng = Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
