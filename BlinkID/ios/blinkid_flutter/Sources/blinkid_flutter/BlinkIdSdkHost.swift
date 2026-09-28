import BlinkID

protocol BlinkIdSdkHost: AnyObject {
  var sdk: BlinkIDSdk? { get }

  /// Refreshes the license lease when the last refresh is older than the refresh interval; nil when not due.
  func refreshLeaseIfDue() async -> Result<Void, Error>?

  func refreshLease() async throws

  /// Terminates the current SDK instance and initializes a new one from `sdkSettings`.
  func reloadSdk(_ sdkSettings: [String: Any]?) async throws -> BlinkIDSdk
}
