import BlinkID

@MainActor
protocol BlinkIdSdkHost: AnyObject {
  /// Runs `operation` after every earlier SDK lifecycle operation (load, unload, reload, license
  /// recovery) has finished and before any later one starts. The members below must only be used
  /// from inside an exclusive operation.
  func runExclusive<T>(_ operation: @escaping @MainActor () async throws -> T) async throws -> T

  var sdk: BlinkIDSdk? { get }

  /// Refreshes the license lease when the last refresh is older than the refresh interval; nil when not due.
  func refreshLeaseIfDue() async -> Result<Void, Error>?

  func refreshLease() async throws

  /// Terminates the current SDK instance and initializes a new one from `sdkSettings`.
  func reloadSdk(_ sdkSettings: [String: Any]?) async throws -> BlinkIDSdk
}
