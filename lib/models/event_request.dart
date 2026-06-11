// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

import '../sdk_info.dart';

part 'event_request.g.dart';

/// Request payload for tracking events
@JsonSerializable(explicitToJson: true)
class EventRequest {
  /// The install ID from attribution
  final String installId;

  /// Name of the event (e.g., "purchase", "signup")
  final String eventName;

  /// Custom event properties (must be JSON-serializable)
  @JsonKey(fromJson: _eventDataFromJson, toJson: _eventDataToJson)
  final Map<String, dynamic> eventData;

  /// ISO 8601 timestamp of when the event occurred
  final String timestamp;

  /// SDK platform identifier (e.g., "flutter"), for backend SDK diagnostics
  final String sdkName;

  /// SDK release version (e.g., "0.2.0"), for backend SDK diagnostics
  final String sdkVersion;

  /// The deep link currently credited for this event (last-click). Null for
  /// organic activity (no deep link has opened the app).
  final String? attributedLinkId;

  /// The originating click id, when known.
  final String? attributedClickId;

  /// ISO 8601 timestamp of when the attributing deep link opened the app.
  final String? linkOpenedAt;

  /// The app-open session this event belongs to (for screen-flow grouping).
  final String? sessionId;

  /// Creates an event request
  EventRequest({
    required this.installId,
    required this.eventName,
    required this.eventData,
    DateTime? timestamp,
    this.sdkName = SdkInfo.name,
    this.sdkVersion = SdkInfo.version,
    this.attributedLinkId,
    this.attributedClickId,
    this.linkOpenedAt,
    this.sessionId,
  }) : timestamp = (timestamp ?? DateTime.now()).toIso8601String();

  /// JSON deserialization
  factory EventRequest.fromJson(Map<String, dynamic> json) =>
      _$EventRequestFromJson(json);

  /// JSON serialization
  Map<String, dynamic> toJson() => _$EventRequestToJson(this);

  /// Ensures eventData values are JSON-serializable
  static Map<String, dynamic> _eventDataFromJson(Map<String, dynamic> json) {
    return json.map((key, value) => MapEntry(key, _sanitizeValue(value)));
  }

  /// Ensures eventData values are JSON-serializable
  static Map<String, dynamic> _eventDataToJson(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _sanitizeValue(value)));
  }

  /// Recursively sanitizes values to ensure JSON compatibility
  static dynamic _sanitizeValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num) return value;
    if (value is bool) return value;
    if (value is List) {
      return value.map(_sanitizeValue).toList();
    }
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _sanitizeValue(val)),
      );
    }
    // Fallback for unsupported types
    return value.toString();
  }

  @override
  String toString() {
    return 'EventRequest(installId: $installId, eventName: $eventName, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRequest &&
          runtimeType == other.runtimeType &&
          installId == other.installId &&
          eventName == other.eventName &&
          timestamp == other.timestamp &&
          sdkName == other.sdkName &&
          sdkVersion == other.sdkVersion &&
          attributedLinkId == other.attributedLinkId &&
          attributedClickId == other.attributedClickId &&
          linkOpenedAt == other.linkOpenedAt &&
          sessionId == other.sessionId &&
          _mapDeepEquals(eventData, other.eventData);

  @override
  int get hashCode =>
      installId.hashCode ^
      eventName.hashCode ^
      timestamp.hashCode ^
      sdkName.hashCode ^
      sdkVersion.hashCode ^
      attributedLinkId.hashCode ^
      attributedClickId.hashCode ^
      linkOpenedAt.hashCode ^
      sessionId.hashCode ^
      _mapDeepHashCode(eventData);

  /// Deep equality comparison for nested maps
  static bool _mapDeepEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final aValue = a[key];
      final bValue = b[key];
      if (aValue is Map && bValue is Map) {
        if (!_mapDeepEquals(
          aValue.cast<String, dynamic>(),
          bValue.cast<String, dynamic>(),
        )) {
          return false;
        }
      } else if (aValue is List && bValue is List) {
        if (!_listDeepEquals(aValue, bValue)) return false;
      } else if (aValue != bValue) {
        return false;
      }
    }
    return true;
  }

  /// Deep equality comparison for lists
  static bool _listDeepEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final aValue = a[i];
      final bValue = b[i];
      if (aValue is Map && bValue is Map) {
        if (!_mapDeepEquals(
          aValue.cast<String, dynamic>(),
          bValue.cast<String, dynamic>(),
        )) {
          return false;
        }
      } else if (aValue is List && bValue is List) {
        if (!_listDeepEquals(aValue, bValue)) return false;
      } else if (aValue != bValue) {
        return false;
      }
    }
    return true;
  }

  /// Deep hash code for nested maps
  static int _mapDeepHashCode(Map<String, dynamic> map) {
    return map.entries.fold(
      0,
      (hash, entry) =>
          hash ^ entry.key.hashCode ^ _valueDeepHashCode(entry.value),
    );
  }

  /// Deep hash code for values (supports nested structures)
  static int _valueDeepHashCode(dynamic value) {
    if (value == null) return 0;
    if (value is Map) return _mapDeepHashCode(value.cast<String, dynamic>());
    if (value is List) {
      return value.fold(0, (hash, item) => hash ^ _valueDeepHashCode(item));
    }
    return value.hashCode;
  }
}
