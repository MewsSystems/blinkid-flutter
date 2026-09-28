/// What the native scanner did to keep the BlinkID license usable.
enum BlinkIdLicenseAction {
  /// Periodic lease refresh before starting a scan session.
  leaseRefresh,

  /// Session creation failed with a license error and the scanner tried to
  /// recover by refreshing the lease and, if needed, reloading the SDK.
  licenseRecovery,
}

/// Reported by [BlinkIdScannerController.licenseEventStream] whenever the
/// native scanner refreshes the license lease or recovers from a license error.
class BlinkIdLicenseEvent {
  const BlinkIdLicenseEvent({
    required this.action,
    required this.isSuccessful,
    this.steps = const [],
    this.error,
  });

  factory BlinkIdLicenseEvent.fromNative(Map<Object?, Object?> payload) => BlinkIdLicenseEvent(
    action: switch (payload['action']) {
      'licenseRecovery' => BlinkIdLicenseAction.licenseRecovery,
      _ => BlinkIdLicenseAction.leaseRefresh,
    },
    isSuccessful: payload['succeeded'] == true,
    steps: [...?(payload['steps'] as List?)?.whereType<String>()],
    error: payload['error'] as String?,
  );

  final BlinkIdLicenseAction action;
  final bool isSuccessful;

  /// Recovery steps attempted, in order: `refresh`, then `reload`.
  final List<String> steps;

  final String? error;

  @override
  String toString() => 'BlinkIdLicenseEvent($action, isSuccessful: $isSuccessful, steps: $steps, error: $error)';
}
