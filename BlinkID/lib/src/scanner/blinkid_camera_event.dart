/// When the native scanner reported its camera state.
enum BlinkIdCameraEventTrigger {
  /// The camera was bound (first bind, permission grant, retry or lens switch).
  configured,

  /// A document finished scanning.
  documentScanned,

  /// The scan was canceled before a document was scanned.
  scanCanceled,
}

/// Camera state reported by [BlinkIdScannerController.cameraEventStream].
///
/// iOS only. On iPhones the back camera may be a virtual multi-lens device that switches to the
/// ultra-wide lens for close focus, so [activeLens] can differ between [BlinkIdCameraEventTrigger.configured]
/// and the end of the scan.
class BlinkIdCameraEvent {
  const BlinkIdCameraEvent({
    required this.trigger,
    required this.deviceType,
    required this.activeLens,
    required this.zoomFactor,
    required this.switchingBehavior,
    this.minimumFocusDistanceMm,
  });

  factory BlinkIdCameraEvent.fromNative(Map<Object?, Object?> payload) => BlinkIdCameraEvent(
    trigger: switch (payload['trigger']) {
      'documentScanned' => BlinkIdCameraEventTrigger.documentScanned,
      'scanCanceled' => BlinkIdCameraEventTrigger.scanCanceled,
      _ => BlinkIdCameraEventTrigger.configured,
    },
    deviceType: payload['deviceType'] as String? ?? 'unknown',
    activeLens: payload['activeLens'] as String? ?? 'unknown',
    zoomFactor: (payload['zoomFactor'] as num?)?.toDouble() ?? 1,
    switchingBehavior: payload['switchingBehavior'] as String? ?? 'unknown',
    minimumFocusDistanceMm: switch (payload['minimumFocusDistanceMm']) {
      final int mm when mm >= 0 => mm,
      _ => null,
    },
  );

  final BlinkIdCameraEventTrigger trigger;

  /// The bound capture device: `triple`, `dualWide`, `wide`, …
  final String deviceType;

  /// The lens currently delivering frames; equals [deviceType] for a single-lens device.
  final String activeLens;

  final double zoomFactor;

  /// Lens switching behavior of a virtual device: `auto`, `unsupported`, …
  final String switchingBehavior;

  /// Closest focus distance of the wide lens, when the OS reports one.
  final int? minimumFocusDistanceMm;

  @override
  String toString() =>
      'BlinkIdCameraEvent($trigger, deviceType: $deviceType, activeLens: $activeLens, zoomFactor: $zoomFactor, '
      'switchingBehavior: $switchingBehavior, minimumFocusDistanceMm: $minimumFocusDistanceMm)';
}
