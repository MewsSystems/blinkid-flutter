import 'package:blinkid_flutter/blinkid_flutter.dart';

/// Holds UI-driven scanning configuration for the BlinkID sample app.
class ScanningModulesConfig {
  ScanningMode scanningMode = ScanningMode.automatic;

  /// Milliseconds before a scanning step times out. `0` disables the timeout.
  int stepTimeoutDuration = 60000;

  /// Milliseconds of UI inactivity before timeout. `0` disables the timeout.
  int inactivityTimeoutDuration = 10000;

  /// Shown at the start of the camera scanning flow (performScan only).
  bool showOnboardingDialog = true;

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

  BlinkIdSessionSettings toSessionSettings() {
    return BlinkIdSessionSettings(
      scanningMode: scanningMode,
      scanningSettings: toScanningSettings(),
      stepTimeoutDuration: stepTimeoutDuration,
      inactivityTimeoutDuration: inactivityTimeoutDuration,
    );
  }

  BlinkIdScanningUxSettings toUxSettings() {
    return BlinkIdScanningUxSettings(
      showHelpButton: true,
      showOnboardingDialog: showOnboardingDialog,
      allowHapticFeedback: true,
      preferredCamera: PreferredCamera.back,
    );
  }

  void resetToDefaults() {
    scanningMode = ScanningMode.automatic;
    stepTimeoutDuration = 60000;
    inactivityTimeoutDuration = 10000;
    showOnboardingDialog = true;
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
