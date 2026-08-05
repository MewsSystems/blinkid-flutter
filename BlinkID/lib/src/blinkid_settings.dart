import 'types.dart';
import 'package:json_annotation/json_annotation.dart';

part 'blinkid_settings.g.dart';

/// Timeout settings for resource downloads.
///
/// Mirrors the native SDKs' `RequestTimeout`. All three values default to
/// `30000` ms — the v8001 native default (raised from `10000` ms in earlier
/// releases).
@JsonSerializable()
class RequestTimeout {
  /// Connection timeout, in milliseconds.
  int connectionTimeoutMilliseconds;

  /// Read timeout, in milliseconds.
  int readTimeoutMilliseconds;

  /// Write timeout, in milliseconds.
  int writeTimeoutMilliseconds;

  RequestTimeout({
    this.connectionTimeoutMilliseconds = 30000,
    this.readTimeoutMilliseconds = 30000,
    this.writeTimeoutMilliseconds = 30000,
  });

  factory RequestTimeout.fromJson(Map<String, dynamic> json) => _$RequestTimeoutFromJson(json);
  Map<String, dynamic> toJson() => _$RequestTimeoutToJson(this);
}

/// Configuration for the SDK's base (non-OTA) resources — the on-device models
/// required for image processing.
@JsonSerializable(explicitToJson: true)
class ResourcesConfig {
  /// Whether resources required for on-device image processing should be downloaded
  /// and cached on first initialization of the SDK.
  ///
  /// If set to `false`, you need to package all the required resources in your
  /// application's assets (see [bundleIdentifier] for iOS).
  bool download;

  /// If resources are to be downloaded, the URL where the resources are hosted.
  String serviceUrl;

  /// Local folder name where resources will be downloaded and cached, within your
  /// application's cache folder.
  String localFolder;

  /// Timeout settings for resource downloads.
  RequestTimeout requestTimeout;

  /// [iOS-specific] If resource downloading is disabled, this defines the bundle
  /// identifier of your iOS app where the resources reside.
  String? bundleIdentifier;

  ResourcesConfig({
    this.download = true,
    this.serviceUrl = 'https://models.cdn.microblink.com/resources',
    this.localFolder = 'MLModels',
    RequestTimeout? requestTimeout,
    this.bundleIdentifier,
  }) : requestTimeout = requestTimeout ?? RequestTimeout();

  factory ResourcesConfig.fromJson(Map<String, dynamic> json) => _$ResourcesConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ResourcesConfigToJson(this);
}

/// Configuration for OTA (over-the-air) resources, letting the SDK download
/// updated document-model resources without requiring an app update.
///
/// OTA is enabled by default ([checkForUpdates]: `true`, [strict]: `false`).
///
/// Notes:
/// - First-run downloads are unavoidable for OTA when resources are missing
///   locally — [checkForUpdates] set to `false` only suppresses *update* checks,
///   not the initial fetch.
/// - [strict] set to `true` changes SDK init to a throwing failure path on a
///   failed OTA download — make sure your error handling accounts for it.
/// - Base resources and OTA resources use distinct hosts ([ResourcesConfig.serviceUrl]
///   vs [serviceUrl]) and distinct cache folders ([ResourcesConfig.localFolder] vs
///   [localFolder]) — don't cross-wire them.
@JsonSerializable(explicitToJson: true)
class OtaResourcesConfig {
  /// When `true`, the SDK checks for and downloads updated OTA resources on init.
  /// When `false`, cached resources are reused as-is with no update check.
  ///
  /// First run is the exception: if resources are missing locally, they are
  /// downloaded regardless of this flag.
  bool checkForUpdates;

  /// Controls failure handling for a failed OTA download during init.
  ///
  /// When `true`, initialization throws if the OTA update fails to download.
  /// When `false` (default), init continues silently and falls back to the
  /// currently bundled/cached version.
  bool strict;

  /// The URL where OTA resources are hosted.
  String serviceUrl;

  /// Local folder name where OTA resources will be downloaded and cached, within
  /// your application's cache folder.
  String localFolder;

  /// Timeout settings for OTA resource downloads.
  RequestTimeout requestTimeout;

  /// [iOS-specific] If resource downloading is disabled, this defines the bundle
  /// identifier of your iOS app where the OTA resources reside.
  String? bundleIdentifier;

  OtaResourcesConfig({
    this.checkForUpdates = true,
    this.strict = false,
    this.serviceUrl = 'https://blinkid-ota.microblink.com',
    this.localFolder = 'OTAMLModels',
    RequestTimeout? requestTimeout,
    this.bundleIdentifier,
  }) : requestTimeout = requestTimeout ?? RequestTimeout();

  factory OtaResourcesConfig.fromJson(Map<String, dynamic> json) => _$OtaResourcesConfigFromJson(json);
  Map<String, dynamic> toJson() => _$OtaResourcesConfigToJson(this);
}

/// Settings for the initialization of the BlinkID SDK.
@JsonSerializable(explicitToJson: true)
class BlinkIdSdkSettings {
  /// License key for the native SDK
  String licenseKey;

  /// Optional licensee string if the provided license key is not tied to the single application ID
  String? licensee;

  /// Configuration for the SDK's base (non-OTA) resources.
  ///
  /// See [ResourcesConfig] for more information.
  ResourcesConfig resourcesConfig;

  /// Configuration for OTA (over-the-air) resources, letting the SDK download
  /// updated document-model resources without requiring an app update.
  ///
  /// See [OtaResourcesConfig] for more information.
  OtaResourcesConfig otaResourcesConfig;

  /// Set a custom HTTPS URL to be used as a proxy for Ping and license checks.
  /// The proxy URL will be applied only if the license has the appropriate rights.
  /// The URL must use the HTTPS protocol. Example: https://your-proxy.com/
  ///
  /// If this value is defined, SDK initialization will not be successful in the following cases:
  ///   - if the URL does not use HTTPS or if the URL is invalid
  ///   - if the license does not allow proxy usage
  String? microblinkProxyUrl;

  /// Settings for the initialization of the BlinkID SDK.
  ///
  /// The `downloadResources` / `resourceDownloadUrl` / `resourceLocalFolder` /
  /// `bundleIdentifier` / `resourceRequestTimeout` constructor parameters are
  /// deprecated as of v8001 — resource configuration now lives on
  /// [resourcesConfig]. They're kept here only as one-time construction
  /// convenience for existing call sites and are folded into [resourcesConfig]
  /// at construction time; prefer passing [resourcesConfig] directly.
  BlinkIdSdkSettings({
    required this.licenseKey,
    this.licensee,
    ResourcesConfig? resourcesConfig,
    OtaResourcesConfig? otaResourcesConfig,
    this.microblinkProxyUrl,
    @Deprecated('Set resourcesConfig.download instead') bool? downloadResources,
    @Deprecated('Set resourcesConfig.serviceUrl instead') String? resourceDownloadUrl,
    @Deprecated('Set resourcesConfig.localFolder instead') String? resourceLocalFolder,
    @Deprecated('Set resourcesConfig.bundleIdentifier instead') String? bundleIdentifier,
    @Deprecated('Set resourcesConfig.requestTimeout instead') int? resourceRequestTimeout,
  }) : resourcesConfig = resourcesConfig ?? ResourcesConfig(),
       otaResourcesConfig = otaResourcesConfig ?? OtaResourcesConfig() {
    if (downloadResources != null) this.resourcesConfig.download = downloadResources;
    if (resourceDownloadUrl != null) this.resourcesConfig.serviceUrl = resourceDownloadUrl;
    if (resourceLocalFolder != null) this.resourcesConfig.localFolder = resourceLocalFolder;
    if (bundleIdentifier != null) this.resourcesConfig.bundleIdentifier = bundleIdentifier;
    if (resourceRequestTimeout != null) {
      this.resourcesConfig.requestTimeout = RequestTimeout(
        connectionTimeoutMilliseconds: resourceRequestTimeout,
        readTimeoutMilliseconds: resourceRequestTimeout,
        writeTimeoutMilliseconds: resourceRequestTimeout,
      );
    }
  }

  factory BlinkIdSdkSettings.fromJson(Map<String, dynamic> json) => _$BlinkIdSdkSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$BlinkIdSdkSettingsToJson(this);
}

/// Represents the configuration settings for a scanning session.
///
/// This class holds the settings related to the resources initialization,
/// scanning mode, and specific scanning configurations that define how the scanning
/// session should behave.
@JsonSerializable(explicitToJson: true)
class BlinkIdSessionSettings {
  /// The scanning mode to be used during the scanning session.
  ///
  /// Specifies whether the scanning is for a single side of a document or multiple
  /// sides, as defined in [ScanningMode]. The default is set to `automatic`, which
  /// automatically determines the number of sides to scan.
  ScanningMode scanningMode = ScanningMode.automatic;

  /// The specific scanning settings for the scanning session.
  ///
  /// Defines various parameters that control the scanning process.
  BlinkIdScanningSettings scanningSettings = BlinkIdScanningSettings();

  /// Duration in seconds before scanning step times out and is cancelled.
  /// If less than zero, scanning will not time out.
  /// Defaults to 60000 (60 seconds)
  int stepTimeoutDuration = 60000;

  ///Duration in seconds of UI inactivity (no state change) before timeout.
  ///If less than or equal to zero, the inactivity timer will not fire.
  /// Defaults to 10000 (10 seconds)
  int inactivityTimeoutDuration = 10000;

  /// Represents the configuration settings for a scanning session.
  ///
  /// This class holds the settings related to the resources initialization,
  /// scanning mode, and specific scanning configurations that define how the scanning
  /// session should behave.
  BlinkIdSessionSettings({
    this.scanningMode = ScanningMode.automatic,
    BlinkIdScanningSettings? scanningSettings,
    this.stepTimeoutDuration = 60000,
    this.inactivityTimeoutDuration = 10000,
  }) : scanningSettings = scanningSettings ?? BlinkIdScanningSettings();

  factory BlinkIdSessionSettings.fromJson(Map<String, dynamic> json) => _$BlinkIdSessionSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$BlinkIdSessionSettingsToJson(this);
}

/// Represents the configurable settings for scanning a document.
///
/// This class defines various parameters and policies related to the scanning
/// process, including image quality handling, data extraction and redaction,
/// along with options for frame processing and image extraction.
// createFactory: false — fromJson is hand-written below. The generated
// factory would always pass an explicit value for every module parameter
// (computed from the JSON, which is `null` for both "key absent" and "key
// present and null"), so it can't tell "leave the constructor's SDK-default
// in place" apart from "explicitly disabled" the way the constructor itself
// can (see the module fields' doc comments and the constructor below).
@JsonSerializable(createFactory: false, explicitToJson: true)
class BlinkIdScanningSettings {
  /// Settings for the document capture module.
  ///
  /// This module is responsible for the initial document detection, image extraction
  /// (such as face and document images), and image quality validation (blur, glare,
  /// and lighting checks).
  /// See [DocumentCaptureModuleSettings] for more information.
  ///
  /// Leave unset for the SDK default (enabled). Pass `documentCaptureModule: null`
  /// explicitly to disable the module.
  DocumentCaptureModuleSettings? documentCaptureModule;

  /// Settings for the MRZ (Machine Readable Zone) extraction module.
  ///
  /// This module is dedicated to the detection and parsing of machine-readable
  /// zone typically found on passports, visas, and identity cards.
  ///
  /// See [MrzModuleSettings] for more information.
  ///
  /// Leave unset for the SDK default (enabled). Pass `mrzModule: null`
  /// explicitly to disable the module.
  MrzModuleSettings? mrzModule;

  /// Settings for the barcode extraction module.
  ///
  /// This module manages the detection and data extraction from various 1D and 2D
  /// barcode formats (such as PDF417, QR codes, and various retail codes).
  ///
  /// It can operate as a standalone module or in combination with document capture.
  ///
  /// See [BarcodeModuleSettings] for more information.
  ///
  /// Leave unset for the SDK default (enabled). Pass `barcodeModule: null`
  /// explicitly to disable the module.
  BarcodeModuleSettings? barcodeModule;

  /// Settings for the VIZ (Visual Inspection Zone) extraction module.
  ///
  /// This module is responsible for extracting data from the document's
  /// visual fields.
  ///
  /// It supports features such as character validation for increased accuracy,
  /// signature image extraction, and data aggregation across multiple video frames.
  ///
  /// See [VizModuleSettings] for more information.
  ///
  /// Leave unset for the SDK default (enabled). Pass `vizModule: null`
  /// explicitly to disable the module.
  VizModuleSettings? vizModule;

  /// The maximum allowed mismatches per field during data matching.
  ///
  /// Configures the maximum number of characters per field that can be inconsistent during data matching.
  ///
  /// By default, no mismatches are allowed.
  int maxAllowedMismatchesPerField;

  BlinkIdScanningSettings({
    this.documentCaptureModule = const DocumentCaptureModuleSettings(),
    this.mrzModule = const MrzModuleSettings(),
    this.barcodeModule = const BarcodeModuleSettings(),
    this.vizModule = const VizModuleSettings(),
    this.maxAllowedMismatchesPerField = 0,
  });

  // Hand-written to preserve the tri-state contract on the way back in:
  // key absent -> leave the constructor's SDK-default instance in place; key
  // present and null -> disabled; key present with a map -> deserialize.
  factory BlinkIdScanningSettings.fromJson(Map<String, dynamic> json) {
    final settings = BlinkIdScanningSettings(
      maxAllowedMismatchesPerField: (json['maxAllowedMismatchesPerField'] as num?)?.toInt() ?? 0,
    );
    if (json.containsKey('documentCaptureModule')) {
      final value = json['documentCaptureModule'];
      settings.documentCaptureModule = value == null
          ? null
          : DocumentCaptureModuleSettings.fromJson(value as Map<String, dynamic>);
    }
    if (json.containsKey('mrzModule')) {
      final value = json['mrzModule'];
      settings.mrzModule = value == null ? null : MrzModuleSettings.fromJson(value as Map<String, dynamic>);
    }
    if (json.containsKey('barcodeModule')) {
      final value = json['barcodeModule'];
      settings.barcodeModule = value == null ? null : BarcodeModuleSettings.fromJson(value as Map<String, dynamic>);
    }
    if (json.containsKey('vizModule')) {
      final value = json['vizModule'];
      settings.vizModule = value == null ? null : VizModuleSettings.fromJson(value as Map<String, dynamic>);
    }
    return settings;
  }

  Map<String, dynamic> toJson() => _$BlinkIdScanningSettingsToJson(this);
}

/// Allows customization of various aspects of the UI/UX
/// used during the scanning process.
@JsonSerializable()
class BlinkIdScanningUxSettings {
  /// A boolean indicating whether to show a help button
  /// and enable help screens during the scanning session.
  ///
  /// Default: `true`
  bool showHelpButton;

  /// A boolean indicating whether to show an onboarding dialog
  /// at the beginning of the scanning session.
  ///
  /// Default: `true`
  bool showOnboardingDialog;

  /// Determines whether haptic feedback is played for scanning-related events.
  ///
  /// When enabled, haptic responses are generated during scanning activities,
  /// such as detection updates or user interactions (e.g., toggling the flashlight).
  /// When disabled, no haptic feedback is produced.
  ///
  /// Default: `true`
  bool allowHapticFeedback;

  /// Determines whether a sound is played for scanning-success events (such as a
  /// side being scanned).
  ///
  /// When disabled, no sound is produced.
  ///
  /// Default: `true`
  bool allowScanSound;

  /// The preferred camera position to use when capturing document.
  /// This value represents the user’s choice of front or back camera.
  ///
  /// The system determines the actual physical camera device.
  ///
  /// Default: [PreferredCamera.back]
  PreferredCamera preferredCamera;

  BlinkIdScanningUxSettings({
    this.allowHapticFeedback = true,
    this.allowScanSound = true,
    this.showHelpButton = true,
    this.showOnboardingDialog = true,
    this.preferredCamera = PreferredCamera.back,
  });

  factory BlinkIdScanningUxSettings.fromJson(Map<String, dynamic> json) => _$BlinkIdScanningUxSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$BlinkIdScanningUxSettingsToJson(this);
}
