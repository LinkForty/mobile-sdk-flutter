// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deep_link_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeepLinkData _$DeepLinkDataFromJson(Map<String, dynamic> json) => DeepLinkData(
  shortCode: json['shortCode'] as String,
  iosURL: json['iosUrl'] as String?,
  androidURL: json['androidUrl'] as String?,
  webURL: json['webUrl'] as String?,
  utmParameters: json['utmParameters'] == null
      ? null
      : UTMParameters.fromJson(json['utmParameters'] as Map<String, dynamic>),
  customParameters: (json['customParameters'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  deepLinkPath: json['deepLinkPath'] as String?,
  appScheme: json['appScheme'] as String?,
  clickedAt: DeepLinkData._dateTimeFromJson(json['clickedAt'] as String?),
  linkId: json['linkId'] as String?,
  confidenceScore: doubleFromJsonOrNull(json['confidenceScore']),
  matchedFactors: stringListFromJsonOrNull(json['matchedFactors']),
  attributionMethod: stringFromJsonOrNull(json['attributionMethod']),
  competingLinks: intFromJsonOrNull(json['competingLinks']),
);

Map<String, dynamic> _$DeepLinkDataToJson(DeepLinkData instance) =>
    <String, dynamic>{
      'shortCode': instance.shortCode,
      'iosUrl': instance.iosURL,
      'androidUrl': instance.androidURL,
      'webUrl': instance.webURL,
      'utmParameters': instance.utmParameters?.toJson(),
      'customParameters': instance.customParameters,
      'deepLinkPath': instance.deepLinkPath,
      'appScheme': instance.appScheme,
      'clickedAt': DeepLinkData._dateTimeToJson(instance.clickedAt),
      'linkId': instance.linkId,
      'confidenceScore': instance.confidenceScore,
      'matchedFactors': instance.matchedFactors,
      'attributionMethod': instance.attributionMethod,
      'competingLinks': instance.competingLinks,
    };
