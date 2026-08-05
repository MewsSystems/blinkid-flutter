// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blinkid_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestTimeout _$RequestTimeoutFromJson(Map<String, dynamic> json) =>
    RequestTimeout(
      connectionTimeoutMilliseconds:
          (json['connectionTimeoutMilliseconds'] as num?)?.toInt() ?? 30000,
      readTimeoutMilliseconds:
          (json['readTimeoutMilliseconds'] as num?)?.toInt() ?? 30000,
      writeTimeoutMilliseconds:
          (json['writeTimeoutMilliseconds'] as num?)?.toInt() ?? 30000,
    );

Map<String, dynamic> _$RequestTimeoutToJson(RequestTimeout instance) =>
    <String, dynamic>{
      'connectionTimeoutMilliseconds': instance.connectionTimeoutMilliseconds,
      'readTimeoutMilliseconds': instance.readTimeoutMilliseconds,
      'writeTimeoutMilliseconds': instance.writeTimeoutMilliseconds,
    };

ResourcesConfig _$ResourcesConfigFromJson(Map<String, dynamic> json) =>
    ResourcesConfig(
      download: json['download'] as bool? ?? true,
      serviceUrl:
          json['serviceUrl'] as String? ??
          'https://models.cdn.microblink.com/resources',
      localFolder: json['localFolder'] as String? ?? 'MLModels',
      requestTimeout: json['requestTimeout'] == null
          ? null
          : RequestTimeout.fromJson(
              json['requestTimeout'] as Map<String, dynamic>,
            ),
      bundleIdentifier: json['bundleIdentifier'] as String?,
    );

Map<String, dynamic> _$ResourcesConfigToJson(ResourcesConfig instance) =>
    <String, dynamic>{
      'download': instance.download,
      'serviceUrl': instance.serviceUrl,
      'localFolder': instance.localFolder,
      'requestTimeout': instance.requestTimeout.toJson(),
      'bundleIdentifier': instance.bundleIdentifier,
    };

OtaResourcesConfig _$OtaResourcesConfigFromJson(Map<String, dynamic> json) =>
    OtaResourcesConfig(
      checkForUpdates: json['checkForUpdates'] as bool? ?? true,
      strict: json['strict'] as bool? ?? false,
      serviceUrl:
          json['serviceUrl'] as String? ?? 'https://blinkid-ota.microblink.com',
      localFolder: json['localFolder'] as String? ?? 'OTAMLModels',
      requestTimeout: json['requestTimeout'] == null
          ? null
          : RequestTimeout.fromJson(
              json['requestTimeout'] as Map<String, dynamic>,
            ),
      bundleIdentifier: json['bundleIdentifier'] as String?,
    );

Map<String, dynamic> _$OtaResourcesConfigToJson(OtaResourcesConfig instance) =>
    <String, dynamic>{
      'checkForUpdates': instance.checkForUpdates,
      'strict': instance.strict,
      'serviceUrl': instance.serviceUrl,
      'localFolder': instance.localFolder,
      'requestTimeout': instance.requestTimeout.toJson(),
      'bundleIdentifier': instance.bundleIdentifier,
    };

BlinkIdSdkSettings _$BlinkIdSdkSettingsFromJson(Map<String, dynamic> json) =>
    BlinkIdSdkSettings(
      licenseKey: json['licenseKey'] as String,
      licensee: json['licensee'] as String?,
      resourcesConfig: json['resourcesConfig'] == null
          ? null
          : ResourcesConfig.fromJson(
              json['resourcesConfig'] as Map<String, dynamic>,
            ),
      otaResourcesConfig: json['otaResourcesConfig'] == null
          ? null
          : OtaResourcesConfig.fromJson(
              json['otaResourcesConfig'] as Map<String, dynamic>,
            ),
      microblinkProxyUrl: json['microblinkProxyUrl'] as String?,
    );

Map<String, dynamic> _$BlinkIdSdkSettingsToJson(BlinkIdSdkSettings instance) =>
    <String, dynamic>{
      'licenseKey': instance.licenseKey,
      'licensee': instance.licensee,
      'resourcesConfig': instance.resourcesConfig.toJson(),
      'otaResourcesConfig': instance.otaResourcesConfig.toJson(),
      'microblinkProxyUrl': instance.microblinkProxyUrl,
    };

BlinkIdSessionSettings _$BlinkIdSessionSettingsFromJson(
  Map<String, dynamic> json,
) => BlinkIdSessionSettings(
  scanningMode:
      $enumDecodeNullable(_$ScanningModeEnumMap, json['scanningMode']) ??
      ScanningMode.automatic,
  scanningSettings: json['scanningSettings'] == null
      ? null
      : BlinkIdScanningSettings.fromJson(
          json['scanningSettings'] as Map<String, dynamic>,
        ),
  stepTimeoutDuration: (json['stepTimeoutDuration'] as num?)?.toInt() ?? 60000,
  inactivityTimeoutDuration:
      (json['inactivityTimeoutDuration'] as num?)?.toInt() ?? 10000,
);

Map<String, dynamic> _$BlinkIdSessionSettingsToJson(
  BlinkIdSessionSettings instance,
) => <String, dynamic>{
  'scanningMode': _$ScanningModeEnumMap[instance.scanningMode]!,
  'scanningSettings': instance.scanningSettings.toJson(),
  'stepTimeoutDuration': instance.stepTimeoutDuration,
  'inactivityTimeoutDuration': instance.inactivityTimeoutDuration,
};

const _$ScanningModeEnumMap = {
  ScanningMode.single: 'single',
  ScanningMode.automatic: 'automatic',
};

Map<String, dynamic> _$BlinkIdScanningSettingsToJson(
  BlinkIdScanningSettings instance,
) => <String, dynamic>{
  'documentCaptureModule': instance.documentCaptureModule?.toJson(),
  'mrzModule': instance.mrzModule?.toJson(),
  'barcodeModule': instance.barcodeModule?.toJson(),
  'vizModule': instance.vizModule?.toJson(),
  'maxAllowedMismatchesPerField': instance.maxAllowedMismatchesPerField,
};

BlinkIdScanningUxSettings _$BlinkIdScanningUxSettingsFromJson(
  Map<String, dynamic> json,
) => BlinkIdScanningUxSettings(
  allowHapticFeedback: json['allowHapticFeedback'] as bool? ?? true,
  allowScanSound: json['allowScanSound'] as bool? ?? true,
  showHelpButton: json['showHelpButton'] as bool? ?? true,
  showOnboardingDialog: json['showOnboardingDialog'] as bool? ?? true,
  preferredCamera:
      $enumDecodeNullable(_$PreferredCameraEnumMap, json['preferredCamera']) ??
      PreferredCamera.back,
);

Map<String, dynamic> _$BlinkIdScanningUxSettingsToJson(
  BlinkIdScanningUxSettings instance,
) => <String, dynamic>{
  'showHelpButton': instance.showHelpButton,
  'showOnboardingDialog': instance.showOnboardingDialog,
  'allowHapticFeedback': instance.allowHapticFeedback,
  'allowScanSound': instance.allowScanSound,
  'preferredCamera': _$PreferredCameraEnumMap[instance.preferredCamera]!,
};

const _$PreferredCameraEnumMap = {
  PreferredCamera.back: 'back',
  PreferredCamera.front: 'front',
};
