import Flutter
import UIKit

public class BlinkIdScannerViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let sdkHost: BlinkIdSdkHost

  init(messenger: FlutterBinaryMessenger, sdkHost: BlinkIdSdkHost) {
    self.messenger = messenger
    self.sdkHost = sdkHost
  }

  public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    let params = args as? [String: Any] ?? [:]
    return BlinkIdScannerView(
      frame: frame,
      viewId: viewId,
      messenger: messenger,
      creationParams: params,
      sdkHost: sdkHost,
    )
  }

  public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}
