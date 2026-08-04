import 'package:flutter/foundation.dart';

/// Guidance states emitted by [BlinkIdScannerController.guidanceStream].
///
/// Android-verified DetectionStatus mapping (from compiled SDK):
///   CameraTooFar              → tooFar
///   CameraTooClose            → tooClose
///   DocumentTooCloseToCameraEdge → tooCloseToEdge
///   CameraAngleTooSteep       → tilted
///   DocumentPartiallyVisible  → notFullyVisible
///   Success / Failed          → searching
///
/// [flipDocument] is NOT a DetectionStatus — it is emitted by the controller
/// when ScanningStatus.SideScanned fires (front side complete). The guidance
/// stream goes silent during the flip phase; use [BlinkIdScanPhase] instead.
///
/// blur / glare / holdStill / lowLight / tooMuchLight are reserved for iOS;
/// Android's DetectionStatus does not include these cases.
sealed class BlinkIdGuidance {
  const BlinkIdGuidance._();

  // --- Android + iOS ---
  const factory BlinkIdGuidance.searching() = BlinkIdGuidanceSearching;
  const factory BlinkIdGuidance.tooFar() = BlinkIdGuidanceTooFar;
  const factory BlinkIdGuidance.tooClose() = BlinkIdGuidanceTooClose;
  const factory BlinkIdGuidance.tooCloseToEdge() = BlinkIdGuidanceTooCloseToEdge;
  const factory BlinkIdGuidance.tilted() = BlinkIdGuidanceTilted;
  const factory BlinkIdGuidance.notFullyVisible() = BlinkIdGuidanceNotFullyVisible;

  // --- Phase-driven (not emitted via stream; use BlinkIdScanPhase.flip) ---
  const factory BlinkIdGuidance.flipDocument() = BlinkIdGuidanceFlipDocument;

  // --- Wrong side (emitted to stream; no phase change) ---
  const factory BlinkIdGuidance.wrongSide() = BlinkIdGuidanceWrongSide;

  // --- iOS only (unconfirmed; pending iOS SDK verification) ---
  const factory BlinkIdGuidance.holdStill() = BlinkIdGuidanceHoldStill;
  const factory BlinkIdGuidance.blur() = BlinkIdGuidanceBlur;
  const factory BlinkIdGuidance.glare() = BlinkIdGuidanceGlare;
  const factory BlinkIdGuidance.lowLight() = BlinkIdGuidanceLowLight;
  const factory BlinkIdGuidance.tooMuchLight() = BlinkIdGuidanceTooMuchLight;

  static BlinkIdGuidance fromString(String value) => switch (value) {
    'searching' => const BlinkIdGuidance.searching(),
    'tooFar' => const BlinkIdGuidance.tooFar(),
    'tooClose' => const BlinkIdGuidance.tooClose(),
    'tooCloseToEdge' => const BlinkIdGuidance.tooCloseToEdge(),
    'tilted' => const BlinkIdGuidance.tilted(),
    'notFullyVisible' => const BlinkIdGuidance.notFullyVisible(),
    'flipDocument' => const BlinkIdGuidance.flipDocument(),
    'wrongSide' => const BlinkIdGuidance.wrongSide(),
    'holdStill' => const BlinkIdGuidance.holdStill(),
    'blur' => const BlinkIdGuidance.blur(),
    'glare' => const BlinkIdGuidance.glare(),
    'lowLight' => const BlinkIdGuidance.lowLight(),
    'tooMuchLight' => const BlinkIdGuidance.tooMuchLight(),
    _ => _unknown(value),
  };

  static BlinkIdGuidance _unknown(String value) {
    assert(() {
      debugPrint('[BlinkID] Unknown guidance value: "$value"');
      return true;
    }());
    return const BlinkIdGuidance.searching();
  }
}

final class BlinkIdGuidanceSearching extends BlinkIdGuidance {
  const BlinkIdGuidanceSearching() : super._();
}

final class BlinkIdGuidanceTooFar extends BlinkIdGuidance {
  const BlinkIdGuidanceTooFar() : super._();
}

final class BlinkIdGuidanceTooClose extends BlinkIdGuidance {
  const BlinkIdGuidanceTooClose() : super._();
}

final class BlinkIdGuidanceTooCloseToEdge extends BlinkIdGuidance {
  const BlinkIdGuidanceTooCloseToEdge() : super._();
}

final class BlinkIdGuidanceTilted extends BlinkIdGuidance {
  const BlinkIdGuidanceTilted() : super._();
}

final class BlinkIdGuidanceNotFullyVisible extends BlinkIdGuidance {
  const BlinkIdGuidanceNotFullyVisible() : super._();
}

final class BlinkIdGuidanceFlipDocument extends BlinkIdGuidance {
  const BlinkIdGuidanceFlipDocument() : super._();
}

final class BlinkIdGuidanceWrongSide extends BlinkIdGuidance {
  const BlinkIdGuidanceWrongSide() : super._();
}

final class BlinkIdGuidanceHoldStill extends BlinkIdGuidance {
  const BlinkIdGuidanceHoldStill() : super._();
}

final class BlinkIdGuidanceBlur extends BlinkIdGuidance {
  const BlinkIdGuidanceBlur() : super._();
}

final class BlinkIdGuidanceGlare extends BlinkIdGuidance {
  const BlinkIdGuidanceGlare() : super._();
}

final class BlinkIdGuidanceLowLight extends BlinkIdGuidance {
  const BlinkIdGuidanceLowLight() : super._();
}

final class BlinkIdGuidanceTooMuchLight extends BlinkIdGuidance {
  const BlinkIdGuidanceTooMuchLight() : super._();
}
