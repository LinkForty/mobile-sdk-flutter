// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

part 'event_response.g.dart';

/// Response from the event tracking endpoint, `{"eventId", "acknowledged"}`.
///
/// A 2xx status means the event was stored; the fields are informational, so
/// both are optional and a reply without them still decodes.
@JsonSerializable()
class EventResponse {
  /// Server-assigned event ID
  final String? eventId;

  /// Whether the server accepted the event
  final bool? acknowledged;

  /// Creates an event response
  const EventResponse({this.eventId, this.acknowledged});

  /// JSON deserialization
  factory EventResponse.fromJson(Map<String, dynamic> json) =>
      _$EventResponseFromJson(json);

  /// JSON serialization
  Map<String, dynamic> toJson() => _$EventResponseToJson(this);

  @override
  String toString() =>
      'EventResponse(eventId: $eventId, acknowledged: $acknowledged)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventResponse &&
          runtimeType == other.runtimeType &&
          eventId == other.eventId &&
          acknowledged == other.acknowledged;

  @override
  int get hashCode => Object.hash(eventId, acknowledged);
}
