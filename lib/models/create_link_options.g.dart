// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_link_options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateLinkOptions _$CreateLinkOptionsFromJson(Map<String, dynamic> json) =>
    CreateLinkOptions(
      templateId: json['templateId'] as String?,
      templateSlug: json['templateSlug'] as String?,
      deepLinkParameters: (json['deepLinkParameters'] as Map<String, dynamic>?)
          ?.map((k, e) => MapEntry(k, e as String)),
      title: json['title'] as String?,
      description: json['description'] as String?,
      customCode: json['customCode'] as String?,
      utmParameters: json['utmParameters'] == null
          ? null
          : UTMParameters.fromJson(
              json['utmParameters'] as Map<String, dynamic>,
            ),
      externalUserId: json['externalUserId'] as String?,
    );

Map<String, dynamic> _$CreateLinkOptionsToJson(CreateLinkOptions instance) =>
    <String, dynamic>{
      'templateId': instance.templateId,
      'templateSlug': instance.templateSlug,
      'deepLinkParameters': instance.deepLinkParameters,
      'title': instance.title,
      'description': instance.description,
      'customCode': instance.customCode,
      'utmParameters': instance.utmParameters?.toJson(),
      'externalUserId': instance.externalUserId,
    };
