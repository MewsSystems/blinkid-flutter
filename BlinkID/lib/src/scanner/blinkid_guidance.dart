sealed class BlinkIdGuidance {
  const BlinkIdGuidance._();

  const factory BlinkIdGuidance.searching() = BlinkIdGuidanceSearching;
  const factory BlinkIdGuidance.tooFar() = BlinkIdGuidanceTooFar;
  const factory BlinkIdGuidance.tooClose() = BlinkIdGuidanceTooClose;
  const factory BlinkIdGuidance.tilted() = BlinkIdGuidanceTilted;
  const factory BlinkIdGuidance.holdStill() = BlinkIdGuidanceHoldStill;
  const factory BlinkIdGuidance.flipDocument() = BlinkIdGuidanceFlipDocument;

  static BlinkIdGuidance fromString(String value) => switch (value) {
    'tooFar' => const BlinkIdGuidance.tooFar(),
    'tooClose' => const BlinkIdGuidance.tooClose(),
    'tilted' => const BlinkIdGuidance.tilted(),
    'holdStill' => const BlinkIdGuidance.holdStill(),
    'flipDocument' => const BlinkIdGuidance.flipDocument(),
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
