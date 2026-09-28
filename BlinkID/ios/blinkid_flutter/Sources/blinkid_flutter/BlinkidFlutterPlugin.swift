import BlinkID
import BlinkIDUX
import Combine
import Flutter
import SwiftUI
import UIKit

public class BlinkIdFlutterPlugin: NSObject, FlutterPlugin {

  private var scanResult: FlutterResult?
  private var rootVc: UIViewController?
  private var classInfoFilterDict: [String: Any]?
  private var redactionSettingsResolverDict: [String: Any]?

  private var blinkIdSdk: BlinkIDSdk?
  private var lastLeaseRefreshAt: Date = .distantPast
  private static let leaseRefreshInterval: TimeInterval = 30 * 60

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "blinkid_flutter", binaryMessenger: registrar.messenger())
    let instance = BlinkIdFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    let factory = BlinkIdScannerViewFactory(messenger: registrar.messenger(), sdkHost: instance)
    registrar.register(factory, withId: "com.microblink.blinkid/scanner_view")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    handleMethodCall(call, result: result)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let method = BlinkIdFlutterMethodChannelArguments(rawValue: call.method) else {
      result(FlutterMethodNotImplemented)
      return
    }

    switch method {
    case .performScan: Task { await performScan(call, result: result) }
    case .directApi: Task { await performDirectApiScan(call, result: result) }
    case .directApiWithAnalysis: Task { await performDirectApiScanWithAnalysis(call, result: result) }
    case .loadSdk: Task { await loadSdk(call, result: result) }
    case .unloadSdk: Task { await unloadSdk(call, result: result) }
    case .refreshLicenseLease: Task { await refreshLicenseLease(result: result) }
    case .deleteCachedResources: deleteCachedResources(call, result: result)
    }
  }

  private func loadSdk(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    do {
      let _ = try await ensureLoadedSdk(call)
      result(true)
    } catch {
      let code = errorCode(for: error)
      if let error = error as? InvalidLicenseKeyError {
        throwFlutterError(
          with: BlinkIdFlutterError.initError(error.message).localizedDescription, code: code,
          result: result)
      } else {
        throwFlutterError(with: error.localizedDescription, code: code, result: result)
      }
    }
  }

  private func refreshLicenseLease(result: @escaping FlutterResult) async {
    do {
      guard blinkIdSdk != nil else {
        throw BlinkIdFlutterError.initError(
          "The BlinkID SDK is not initialized. Call the loadBlinkIdSdk() method to pre-load the SDK first, or perform a scan."
        )
      }
      try await refreshLease()
      result(true)
    } catch let blinkIdError as BlinkIdFlutterError {
      throwFlutterError(with: blinkIdError.localizedDescription, result: result)
    } catch {
      let code = errorCode(for: error)
      if let sdkError = error as? InvalidLicenseKeyError {
        throwFlutterError(with: sdkError.message, code: code, result: result)
      } else {
        throwFlutterError(with: error.localizedDescription, code: code, result: result)
      }
    }
  }

  private func unloadSdk(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    let arguments = call.arguments as? [String: Any]
    let deleteResources = (arguments?["deleteCachedResources"] as? Bool) ?? false
    if deleteResources {
      await BlinkIDSdk.terminateBlinkIDSdkAndDeleteCachedResources()
    } else {
      await BlinkIDSdk.terminateBlinkIDSdk()
    }
    blinkIdSdk = nil
    result(true)
  }

  private func ensureLoadedSdk(_ call: FlutterMethodCall) async throws -> BlinkIDSdk? {
    if let blinkIdSdk = blinkIdSdk { return blinkIdSdk }

    do {
      guard let settings = try await setupBlinkIdSettings(call) else {
        throw BlinkIdFlutterError.incorrectArgument("Incorrect BlinkID SDK settings!")
      }
      blinkIdSdk = try await BlinkIDSdk.createBlinkIDSdk(withSettings: settings)
      lastLeaseRefreshAt = Date()
      return blinkIdSdk
    } catch {
      blinkIdSdk = nil
      throw error
    }
  }

  private func setupBlinkIdSettings(_ call: FlutterMethodCall) async throws -> BlinkIDSdkSettings? {
    guard let rawArgs = call.arguments as? [String: Any],
      let arguments = BlinkIdDeserializationUtils.sanitizeDictionary(rawArgs)
    else {
      throw BlinkIdFlutterError.incorrectArgument("Flutter raw arguments")
    }

    guard let sdkSettingsRaw = arguments["blinkIdSdkSettings"] as? [String: Any],
      let sdkSettingsDict = BlinkIdDeserializationUtils.sanitizeDictionary(sdkSettingsRaw),
      let settings = BlinkIdDeserializationUtils.deserializeBlinkIdSdkSettings(sdkSettingsDict)
    else {
      throw BlinkIdFlutterError.incorrectArgument("BlinkID SDK settings")
    }
    return settings
  }

  private func performScan(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    if scanResult != nil {
      throwFlutterError(with: "A BlinkID scan is already in progress.", result: result)
      return
    }

    guard let arguments = call.arguments as? [String: Any],
      let cleanArguments = BlinkIdDeserializationUtils.sanitizeDictionary(arguments)
    else {
      throwFlutterError(
        with: BlinkIdFlutterError.incorrectArgument("Flutter raw arguments").localizedDescription,
        result: result)
      return
    }

    scanResult = result

    do {
      guard let blinkIdSdk = try await ensureLoadedSdk(call) else {
        throw BlinkIdFlutterError.initError(
          "The BlinkID SDK is not initialized. Call the loadBlinkIdSdk() method to pre-load the SDK first, or try running the performScan() method with a valid internet connection."
        )
      }

      guard let sessionSettingsRaw = cleanArguments["blinkIdSessionSettings"] as? [String: Any],
        let sessionSettings = BlinkIdDeserializationUtils.sanitizeDictionary(sessionSettingsRaw)
      else {
        throw BlinkIdFlutterError.incorrectArgument("BlinkID session settings")
      }
      #if DEBUG
      print("[BlinkIdFlutter] performScan received blinkIdSessionSettings=\(sessionSettings)")
      #endif

      let uxSettings = BlinkIdDeserializationUtils.deserializeBlinkIdUxScanningSettings(
        cleanArguments["blinkIdScanningUxSettings"] as? [String: Any])

      classInfoFilterDict = cleanArguments["blinkIdClassFilter"] as? [String: Any]
      redactionSettingsResolverDict = BlinkIdDeserializationUtils.toStringKeyedMap(
        cleanArguments["blinkIdRedactionSettingsResolver"]
      )
      #if DEBUG
      print(
        "[BlinkIdFlutter] performScan received blinkIdRedactionSettingsResolver=\(String(describing: redactionSettingsResolverDict))"
      )
      #endif
      let analyzer = try await BlinkIDAnalyzer(
        sdk: blinkIdSdk,
        blinkIdSessionSettings: BlinkIdDeserializationUtils.deserializeBlinkIdSessionSettings(
          sessionSettings, source: "performScan"),
        eventStream: BlinkIDEventStream(),
        classFilter: self,
        redactionSettingsResolver: self
      )

      await addFlutterPinglet(with: analyzer.sessionNumber)

      let scanningUxModel = await BlinkIDUXModel(
        analyzer: analyzer,
        uxSettings: uxSettings
      ) { blinkIdState in
        DispatchQueue.main.async { [weak self] in
          if blinkIdState.scanningResult != nil {
            self?.completeScan(
              with: BlinkIdSerializationUtils.serializeBlinkIdScanningResult(
                blinkIdState.scanningResult))
            self?.rootVc?.dismiss(animated: true)
          } else {
            Task { await BlinkIDSdk.terminateBlinkIDSdk() }
            self?.blinkIdSdk = nil
            self?.completeScanWithError(BlinkIdFlutterError.scanningCancelled.localizedDescription)
            self?.rootVc?.dismiss(animated: true)
          }

        }

      }

      DispatchQueue.main.async {
        if !self.presentScanningUI(scanningUxModel) {
          self.completeScanWithError("Could not present the scanning UI.")
        }
      }

    } catch {
      if let error = error as? InvalidLicenseKeyError {
        completeScanWithError(BlinkIdFlutterError.initError(error.message).localizedDescription)
      } else {
        completeScanWithError(error.localizedDescription)
      }
    }
  }

  @discardableResult
  private func presentScanningUI(_ model: BlinkIDUXModel) -> Bool {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: \.isKeyWindow)
    guard let rootVC = keyWindow?.rootViewController else {
      return false
    }

    self.rootVc = rootVC

    let viewController = UIHostingController(rootView: BlinkIDUXView(viewModel: model))
    viewController.modalPresentationStyle = .fullScreen
    rootVC.present(viewController, animated: true)
    return true
  }

  func performDirectApiScan(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    await runDirectApiScan(call, includeAnalysis: false, result: result)
  }

  /// Behaves like `performDirectApiScan`, but the success payload is
  /// `{"result": <scanning result JSON>, "analysis": <analysis JSON>}` instead of the bare
  /// scanning-result JSON.
  func performDirectApiScanWithAnalysis(_ call: FlutterMethodCall, result: @escaping FlutterResult)
    async
  {
    await runDirectApiScan(call, includeAnalysis: true, result: result)
  }

  private func runDirectApiScan(
    _ call: FlutterMethodCall, includeAnalysis: Bool, result: @escaping FlutterResult
  ) async {
    guard let arguments = call.arguments as? [String: Any],
      let argumentsClean = BlinkIdDeserializationUtils.sanitizeDictionary(arguments)
    else {
      throwFlutterError(
        with: BlinkIdFlutterError.incorrectArgument("Flutter raw arguments").localizedDescription,
        result: result)
      return
    }
    do {
      guard let blinkIdSdk = try await ensureLoadedSdk(call) else {
        throw BlinkIdFlutterError.initError(
          "The BlinkID SDK is not initialized. Call the loadBlinkIdSdk() method to pre-load the SDK first, or try running the performDirectApiScan() method with a valid internet connection."
        )
      }

      guard let sessionSettingsRaw = argumentsClean["blinkIdSessionSettings"] as? [String: Any],
        let sessionSettingsClean = BlinkIdDeserializationUtils.sanitizeDictionary(
          sessionSettingsRaw)
      else {
        throw BlinkIdFlutterError.incorrectArgument("BlinkID session settings")
      }

      let sessionSettings = BlinkIdDeserializationUtils.deserializeBlinkIdSessionSettings(
        sessionSettingsClean, source: "directApi", isDirectApi: true)
      let session = try await blinkIdSdk.createScanningSession(sessionSettings: sessionSettings)

      await addFlutterPinglet(with: session.getSessionNumber())

      guard
        let frontUIImage = BlinkIdDeserializationUtils.deserializeBase64Image(
          argumentsClean["firstImage"] as? String)
      else {
        throw BlinkIdFlutterError.frontImageError
      }

      var lastFrameResult = try await session.process(inputImage: InputImage(uiImage: frontUIImage))

      if let backUIImage = BlinkIdDeserializationUtils.deserializeBase64Image(
        argumentsClean["secondImage"] as? String)
      {
        lastFrameResult = try await session.process(inputImage: InputImage(uiImage: backUIImage))
      }

      var redactionSettings: RedactionSettings?
      if let redactionSettingsDict = argumentsClean["directApiRedactionSettings"] as? [String: Any]
      {
        redactionSettings = BlinkIdDeserializationUtils.deserializeRedactionSettings(
          redactionSettingsDict)
      }

      let scannedResults = await session.getResult(redactionSettings: redactionSettings)

      if includeAnalysis {
        var payload: [String: Any] = [:]
        payload["result"] = BlinkIdSerializationUtils.serializeBlinkIdScanningResultDict(scannedResults)
        payload["analysis"] = BlinkIdSerializationUtils.serializeInputImageAnalysisResult(
          lastFrameResult.processResult?.inputImageAnalysisResult)
        DispatchQueue.main.async {
          result(BlinkIdSerializationUtils.encodeToJson(payload))
        }
      } else {
        DispatchQueue.main.async {
          result(BlinkIdSerializationUtils.serializeBlinkIdScanningResult(scannedResults))
        }
      }
    } catch {
      if let error = error as? InvalidLicenseKeyError {
        throwFlutterError(with: error.message, result: result)
      } else {
        throwFlutterError(with: error.localizedDescription, result: result)
      }
    }
  }

  // Deletes cached SDK resources from disk without requiring the SDK to be initialized — a plain
  // static utility on BlinkIDSdk (unlike unloadSdk, it never touches the live `blinkIdSdk`
  // instance), safe to call at any time, e.g. on logout or storage cleanup.
  private func deleteCachedResources(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    let resourcesLocalFolder = (arguments?["resourcesLocalFolder"] as? String) ?? "MLModels"
    let otaResourcesLocalFolder = (arguments?["otaResourcesLocalFolder"] as? String) ?? "OTAMLModels"
    BlinkIDSdk.deleteCachedResources(
      resourcesLocalFolder: resourcesLocalFolder,
      otaResourcesLocalFolder: otaResourcesLocalFolder)
    result(true)
  }

  private func addFlutterPinglet(with sessionNumber: Int) async {
    await PingManager.shared.addPinglet(
      pinglet: WrapperProductInfoPinglet(wrapperProduct: .crossplatformflutter),
      sessionNumber: sessionNumber)
  }

  private func completeScan(with value: Any?) {
    scanResult?(value)
    scanResult = nil
  }

  private func completeScanWithError(_ message: String) {
    scanResult?(
      FlutterError(
        code: BlinkIdFlutterError.iosErrorName,
        message: message,
        details: nil))
    scanResult = nil
  }

  private func errorCode(for error: Error) -> String {
    isBlinkIdLicenseError(error) ? blinkIdLicenseErrorCode : BlinkIdFlutterError.iosErrorName
  }

  private func throwFlutterError(
    with message: String, code: String = BlinkIdFlutterError.iosErrorName,
    result: @escaping FlutterResult
  ) {
    result(
      FlutterError(
        code: code,
        message: message,
        details: nil))
  }
}

extension BlinkIdFlutterPlugin: BlinkIdSdkHost {
  var sdk: BlinkIDSdk? { blinkIdSdk }

  func refreshLeaseIfDue() async -> Result<Void, Error>? {
    guard Date().timeIntervalSince(lastLeaseRefreshAt) >= Self.leaseRefreshInterval else { return nil }
    do {
      try await refreshLease()
      return .success(())
    } catch {
      return .failure(error)
    }
  }

  func refreshLease() async throws {
    try await BlinkIDSdk.refreshLicenseLease()
    lastLeaseRefreshAt = Date()
  }

  func reloadSdk(_ sdkSettings: [String: Any]?) async throws -> BlinkIDSdk {
    await BlinkIDSdk.terminateBlinkIDSdk()
    blinkIdSdk = nil
    guard let sdkSettings,
      let sanitized = BlinkIdDeserializationUtils.sanitizeDictionary(sdkSettings),
      let settings = BlinkIdDeserializationUtils.deserializeBlinkIdSdkSettings(sanitized)
    else {
      throw BlinkIdFlutterError.incorrectArgument("BlinkID SDK settings")
    }
    let sdk = try await BlinkIDSdk.createBlinkIDSdk(withSettings: settings)
    blinkIdSdk = sdk
    lastLeaseRefreshAt = Date()
    return sdk
  }
}

extension BlinkIdFlutterPlugin: BlinkIDClassFilter {
  public func classAllowed(classInfo: BlinkID.BlinkIDSDK.DocumentClassInfo) -> Bool {
    if let classInfoFilterDict = classInfoFilterDict {
      return BlinkIdDeserializationUtils.deserializeClassFilter(classInfoFilterDict, classInfo)
    }
    return true
  }
}

extension BlinkIdFlutterPlugin: RedactionSettingsResolver {
  public func resolveRedactionSettings(classInfo: BlinkID.BlinkIDSDK.DocumentClassInfo) -> BlinkID
    .RedactionSettings?
  {
    return BlinkIdDeserializationUtils.deserializeRedactionSettingsResolver(
      redactionSettingsResolverDict, classInfo)
  }
}

enum BlinkIdFlutterMethodChannelArguments: String {
  case performScan = "performScan"
  case directApi = "performDirectApiScan"
  case directApiWithAnalysis = "performDirectApiScanWithAnalysis"
  case loadSdk = "loadBlinkIdSdk"
  case unloadSdk = "unloadBlinkIdSdk"
  case refreshLicenseLease = "refreshLicenseLease"
  case deleteCachedResources = "deleteCachedResources"
}

enum BlinkIdFlutterError: LocalizedError {
  case incorrectArgument(String)
  case settingsError
  case initError(String)
  case frontImageError
  case scanningCancelled

  var localizedDescription: String {
    switch self {
    case .incorrectArgument(let argument):
      return "Incorrect argument passed for \(argument)"
    case .settingsError:
      return "Invalid SDK settings provided"
    case .initError(let initErrorReason):
      return "Could not initialize the SDK. Reason: \(initErrorReason)"
    case .frontImageError:
      return
        "Could not extract the information from the first image! An image of a valid document needs to be sent."
    case .scanningCancelled:
      return "Scanning has been cancelled"
    }
  }

  static var iosErrorName: String {
    return "blinkid_ios_error"
  }
}
