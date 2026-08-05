// Verifies the tri-state module contract on BlinkIdScanningSettings: leaving
// a module unset serializes as the SDK-default enabled settings, explicitly
// passing null serializes as an explicit JSON null (disables the module
// natively — see BlinkIdDeserializationUtils on both platforms), and passing
// settings serializes those settings. Also verifies the round trip back
// through fromJson, which is hand-written specifically to preserve this
// contract (see blinkid_settings.dart).
import 'package:blinkid_flutter/blinkid_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlinkIdScanningSettings module contract', () {
    test('unset module serializes as the SDK-default enabled settings, not omitted', () {
      final json = BlinkIdScanningSettings().toJson();

      expect(json.containsKey('barcodeModule'), isTrue);
      expect(json['barcodeModule'], isNotNull);
      expect(json['documentCaptureModule'], isNotNull);
      expect(json['mrzModule'], isNotNull);
      expect(json['vizModule'], isNotNull);
    });

    test('explicit null disables the module: key present, value null', () {
      final json = BlinkIdScanningSettings(barcodeModule: null).toJson();

      expect(json.containsKey('barcodeModule'), isTrue);
      expect(json['barcodeModule'], isNull);
      // Unrelated modules stay on the SDK default.
      expect(json['documentCaptureModule'], isNotNull);
    });

    test('an explicit settings object round-trips through toJson', () {
      final settings = BlinkIdScanningSettings(barcodeModule: BarcodeModuleSettings(presenceMandatory: true));
      final json = settings.toJson();

      expect(json['barcodeModule'], isA<Map<String, dynamic>>());
      expect((json['barcodeModule'] as Map)['presenceMandatory'], isTrue);
    });

    test('fromJson preserves unset vs. explicit-null vs. present on the way back in', () {
      // Unset: key genuinely absent from the JSON map.
      final unset = BlinkIdScanningSettings.fromJson(const {});
      expect(unset.documentCaptureModule, isNotNull);
      expect(unset.barcodeModule, isNotNull);

      // Explicit null: key present, value null.
      final disabled = BlinkIdScanningSettings.fromJson(const {'barcodeModule': null});
      expect(disabled.barcodeModule, isNull);
      // Everything else the caller didn't mention stays SDK-default enabled.
      expect(disabled.documentCaptureModule, isNotNull);

      // Present map: deserialized into real settings.
      final withMap = BlinkIdScanningSettings.fromJson({
        'barcodeModule': {'presenceMandatory': true},
      });
      expect(withMap.barcodeModule, isNotNull);
      expect(withMap.barcodeModule!.presenceMandatory, isTrue);
    });

    test('toJson -> fromJson round trip is stable for a disabled module', () {
      final original = BlinkIdScanningSettings(vizModule: null);
      final roundTripped = BlinkIdScanningSettings.fromJson(original.toJson());

      expect(roundTripped.vizModule, isNull);
      expect(roundTripped.barcodeModule, isNotNull);
    });
  });

  group('DocumentCaptureModuleSettings v8001 nullable rejection flags', () {
    test('imageWith*Rejected default to null (SDK-resolved), not true', () {
      final json = DocumentCaptureModuleSettings().toJson();

      expect(json['imageWithBlurRejected'], isNull);
      expect(json['imageWithGlareRejected'], isNull);
      expect(json['imageWithHandOcclusionRejected'], isNull);
      // This one genuinely defaults to true on both native SDKs — not part of the tri-state group.
      expect(json['imageWithPoorLightingRejected'], isTrue);
    });

    test('inputImageMargin defaults to null (SDK-resolved), not the old hardcoded 0.02', () {
      expect(DocumentCaptureModuleSettings().toJson()['inputImageMargin'], isNull);
    });

    test('cropType defaults to notCropped and serializes as a string', () {
      expect(DocumentCaptureModuleSettings().toJson()['cropType'], 'notCropped');
    });

    test('inputImageSelectionStrategy defaults to balanced', () {
      expect(DocumentCaptureModuleSettings().toJson()['inputImageSelectionStrategy'], 'balanced');
    });
  });

  group('VizModuleSettings v8001 nullable resultAggregationEnabled', () {
    test('defaults to null (SDK-resolved), not the old hardcoded true', () {
      expect(VizModuleSettings().toJson()['resultAggregationEnabled'], isNull);
    });
  });

  group('BarcodeModuleSettings v8001 aztecScanningEnabled', () {
    test('defaults to false and is present in the serialized settings', () {
      expect(BarcodeModuleSettings().toJson()['aztecScanningEnabled'], isFalse);
    });
  });

  group('BlinkIdScanningUxSettings v8001 allowScanSound', () {
    test('defaults to true and is present in the serialized settings', () {
      expect(BlinkIdScanningUxSettings().toJson()['allowScanSound'], isTrue);
    });
  });

  group('BlinkIdSdkSettings v8001 resource config restructure', () {
    test('nests resourcesConfig / otaResourcesConfig with the documented defaults', () {
      final json = BlinkIdSdkSettings(licenseKey: 'x').toJson();

      final resourcesConfig = json['resourcesConfig'] as Map;
      expect(resourcesConfig['download'], isTrue);
      expect(resourcesConfig['serviceUrl'], 'https://models.cdn.microblink.com/resources');
      expect(resourcesConfig['localFolder'], 'MLModels');
      final requestTimeout = resourcesConfig['requestTimeout'] as Map;
      expect(requestTimeout['connectionTimeoutMilliseconds'], 30000);
      expect(requestTimeout['readTimeoutMilliseconds'], 30000);
      expect(requestTimeout['writeTimeoutMilliseconds'], 30000);

      final otaResourcesConfig = json['otaResourcesConfig'] as Map;
      expect(otaResourcesConfig['checkForUpdates'], isTrue);
      expect(otaResourcesConfig['strict'], isFalse);
      expect(otaResourcesConfig['serviceUrl'], 'https://blinkid-ota.microblink.com');
      expect(otaResourcesConfig['localFolder'], 'OTAMLModels');
    });

    test('deprecated flat constructor params fold into resourcesConfig, not serialized separately', () {
      final settings = BlinkIdSdkSettings(
        licenseKey: 'x',
        // ignore: deprecated_member_use_from_same_package
        downloadResources: false,
        // ignore: deprecated_member_use_from_same_package
        resourceDownloadUrl: 'https://custom.example.com',
        // ignore: deprecated_member_use_from_same_package
        resourceLocalFolder: 'CustomFolder',
        // ignore: deprecated_member_use_from_same_package
        resourceRequestTimeout: 5000,
      );
      final json = settings.toJson();

      expect(json.containsKey('downloadResources'), isFalse);
      expect(json.containsKey('resourceDownloadUrl'), isFalse);
      expect(json.containsKey('resourceLocalFolder'), isFalse);
      expect(json.containsKey('resourceRequestTimeout'), isFalse);

      final resourcesConfig = json['resourcesConfig'] as Map;
      expect(resourcesConfig['download'], isFalse);
      expect(resourcesConfig['serviceUrl'], 'https://custom.example.com');
      expect(resourcesConfig['localFolder'], 'CustomFolder');
      final requestTimeout = resourcesConfig['requestTimeout'] as Map;
      expect(requestTimeout['connectionTimeoutMilliseconds'], 5000);
      expect(requestTimeout['readTimeoutMilliseconds'], 5000);
      expect(requestTimeout['writeTimeoutMilliseconds'], 5000);
    });
  });
}
