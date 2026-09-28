import BlinkID

@MainActor
protocol BlinkIdSdkHost: AnyObject {
  var sdk: BlinkIDSdk? { get }

  /// Incremented whenever the SDK is unloaded or terminated outside license recovery.
  var sdkGeneration: Int { get }

  /// The current SDK once any in-flight reload or termination has finished.
  func resolveSdk() async -> BlinkIDSdk?

  /// Refreshes the license lease when the last refresh is older than the refresh interval; nil when not due.
  func refreshLeaseIfDue() async -> Result<Void, Error>?

  func refreshLease() async throws

  /// Terminates the current SDK instance and initializes a new one from `sdkSettings`.
  /// Throws when the SDK was unloaded since `expectedGeneration` was read.
  func reloadSdk(_ sdkSettings: [String: Any]?, expectedGeneration: Int) async throws -> BlinkIDSdk
}
