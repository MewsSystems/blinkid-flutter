sealed class BlinkIdGuidance {
  const BlinkIdGuidance._();

  const factory BlinkIdGuidance.searching() = BlinkIdGuidanceSearching;
  const factory BlinkIdGuidance.tooFar() = BlinkIdGuidanceTooFar;
  const factory BlinkIdGuidance.tooClose() = BlinkIdGuidanceTooClose;
  const factory BlinkIdGuidance.tilted() = BlinkIdGuidanceTilted;
  const factory BlinkIdGuidance.holdStill() = BlinkIdGuidanceHoldStill;
  const factory BlinkIdGuidance.flipDocument() = BlinkIdGuidanceFlipDocument;
  const factory BlinkIdGuidance.blur() = BlinkIdGuidanceBlur;
  const factory BlinkIdGuidance.glare() = BlinkIdGuidanceGlare;
  const factory BlinkIdGuidance.notFullyVisible() = BlinkIdGuidanceNotFullyVisible;
  const factory BlinkIdGuidance.tooCloseToEdge() = BlinkIdGuidanceTooCloseToEdge;
  const factory BlinkIdGuidance.lowLight() = BlinkIdGuidanceLowLight;
  const factory BlinkIdGuidance.tooMuchLight() = BlinkIdGuidanceTooMuchLight;

  static BlinkIdGuidance fromString(String value) => switch (value) {
    'tooFar' => const BlinkIdGuidance.tooFar(),
    'tooClose' => const BlinkIdGuidance.tooClose(),
    'tilted' => const BlinkIdGuidance.tilted(),
    'holdStill' => const BlinkIdGuidance.holdStill(),
    'flipDocument' => const BlinkIdGuidance.flipDocument(),
    'blur' => const BlinkIdGuidance.blur(),
    'glare' => const BlinkIdGuidance.glare(),
    'notFullyVisible' => const BlinkIdGuidance.notFullyVisible(),
    'tooCloseToEdge' => const BlinkIdGuidance.tooCloseToEdge(),
    'lowLight' => const BlinkIdGuidance.lowLight(),
    'tooMuchLight' => const BlinkIdGuidance.tooMuchLight(),
    _ => const BlinkIdGuidance.searching(),
  };
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

final class BlinkIdGuidanceTilted extends BlinkIdGuidance {
  const BlinkIdGuidanceTilted() : super._();
}

final class BlinkIdGuidanceHoldStill extends BlinkIdGuidance {
  const BlinkIdGuidanceHoldStill() : super._();
}

final class BlinkIdGuidanceFlipDocument extends BlinkIdGuidance {
  const BlinkIdGuidanceFlipDocument() : super._();
}

final class BlinkIdGuidanceBlur extends BlinkIdGuidance {
  const BlinkIdGuidanceBlur() : super._();
}

final class BlinkIdGuidanceGlare extends BlinkIdGuidance {
  const BlinkIdGuidanceGlare() : super._();
}

final class BlinkIdGuidanceNotFullyVisible extends BlinkIdGuidance {
  const BlinkIdGuidanceNotFullyVisible() : super._();
}

final class BlinkIdGuidanceTooCloseToEdge extends BlinkIdGuidance {
  const BlinkIdGuidanceTooCloseToEdge() : super._();
}

final class BlinkIdGuidanceLowLight extends BlinkIdGuidance {
  const BlinkIdGuidanceLowLight() : super._();
}

final class BlinkIdGuidanceTooMuchLight extends BlinkIdGuidance {
  const BlinkIdGuidanceTooMuchLight() : super._();
}
