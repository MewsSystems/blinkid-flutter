import 'package:blinkid_flutter/blinkid_flutter.dart';

/// Holds UI-driven scanning module configuration for the BlinkID sample app.
class ScanningModulesConfig {
  ScanningMode scanningMode = ScanningMode.automatic;

  bool barcodeEnabled = true;
  BarcodeModuleSettings barcode = BarcodeModuleSettings(
    presenceMandatory: true,
    pdf417ScanningEnabled: true,
  );

  bool documentCaptureEnabled = true;
  DocumentCaptureModuleSettings documentCapture =
      DocumentCaptureModuleSettings(documentImageReturnEnabled: true);

  bool mrzEnabled = true;
  MrzModuleSettings mrz = MrzModuleSettings(presenceMandatory: true);

  bool vizEnabled = true;
  VizModuleSettings viz = VizModuleSettings(presenceMandatory: true);

  BlinkIdScanningSettings toScanningSettings() {
    return BlinkIdScanningSettings(
      barcodeModule: barcodeEnabled ? barcode : null,
      documentCaptureModule:
          documentCaptureEnabled ? documentCapture : null,
      mrzModule: mrzEnabled ? mrz : null,
      vizModule: vizEnabled ? viz : null,
    );
  }

  void resetToDefaults() {
    scanningMode = ScanningMode.automatic;
    barcodeEnabled = true;
    barcode = BarcodeModuleSettings(
      presenceMandatory: true,
      pdf417ScanningEnabled: true,
    );

    documentCaptureEnabled = true;
    documentCapture = DocumentCaptureModuleSettings(
      documentImageReturnEnabled: true,
    );

    mrzEnabled = true;
    mrz = MrzModuleSettings(presenceMandatory: true);

    vizEnabled = true;
    viz = VizModuleSettings(presenceMandatory: true);
  }
}
