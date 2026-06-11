// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventRequest _$EventRequestFromJson(Map<String, dynamic> json) => EventRequest(
      installId: json['installId'] as String,
      eventName: json['eventName'] as String,
      eventData: EventRequest._eventDataFromJson(
          json['eventData'] as Map<String, dynamic>),
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      sdkName: json['sdkName'] as String? ?? SdkInfo.name,
      sdkVersion: json['sdkVersion'] as String? ?? SdkInfo.version,
      attributedLinkId: json['attributedLinkId'] as String?,
      attributedClickId: json['attributedClickId'] as String?,
      linkOpenedAt: json['linkOpenedAt'] as String?,
      sessionId: json['sessionId'] as String?,
    );

Map<String, dynamic> _$EventRequestToJson(EventRequest instance) =>
    <String, dynamic>{
      'installId': instance.installId,
      'eventName': instance.eventName,
      'eventData': EventRequest._eventDataToJson(instance.eventData),
      'timestamp': instance.timestamp,
      'sdkName': instance.sdkName,
      'sdkVersion': instance.sdkVersion,
      'attributedLinkId': instance.attributedLinkId,
      'attributedClickId': instance.attributedClickId,
      'linkOpenedAt': instance.linkOpenedAt,
      'sessionId': instance.sessionId,
    };
