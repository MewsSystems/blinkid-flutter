import Flutter
import UIKit

public class MicroblinkScannerViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    
    @objc public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
    
    
    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return MicroblinkScannerView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }
}

class MicroblinkScannerView: NSObject,
                             FlutterPlatformView,
                             CustomOverlayViewControllerDelegate {
    
    private let controller = UIViewController()
    private let channel: FlutterMethodChannel
    private var recognizerCollection: MBRecognizerCollection?
    private var overlayViewController: CustomOverlayViewController?
    
    private var statusHandler: DetectionStatusStreamHandler
    private var resulstHandler: ResultsStreamHandler
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        controller.view = UIView()
        
        let channelBaseName = "MicroblinkScannerWidget/\(String(viewId))";
        
        self.channel = FlutterMethodChannel(name: "\(channelBaseName)/method", binaryMessenger: messenger)
        
        let statusEventChannel = FlutterEventChannel(name: "\(channelBaseName)/events/status", binaryMessenger: messenger)
        let resultsEventChannel = FlutterEventChannel(name: "\(channelBaseName)/events/scan", binaryMessenger: messenger)
        
        self.statusHandler = DetectionStatusStreamHandler()
        self.resulstHandler = ResultsStreamHandler()
        
        
        let arguments = args as! [AnyHashable : Any]
        MBMicroblinkSDK.shared().setLicenseKey(arguments["licenseKey"] as! String, errorCallback: { _ in })
        
        let recognizerCollectionDict = arguments["recognizerCollection"] as! [AnyHashable : Any]
        self.recognizerCollection = MBRecognizerSerializers.sharedInstance().deserializeRecognizerCollection(recognizerCollectionDict)!
        
        super.init()
        
        self.channel.setMethodCallHandler(self.methodHandler)
        statusEventChannel.setStreamHandler(self.statusHandler)
        resultsEventChannel.setStreamHandler(self.resulstHandler)
        
        
        let settingsDict = arguments["overlaySettings"] as! [AnyHashable : Any]
        self.prepare(frame: frame, jsonSettings: settingsDict)
    }
    
    func view() -> UIView {
        return controller.view
    }
    
    func prepare(frame: CGRect, jsonSettings: [AnyHashable : Any]) {
        let settings = MBOverlaySettings()
        
        MBOverlaySerializationUtils.extractCommonOverlaySettings(jsonSettings, overlaySettings: settings)
        
        settings.cameraSettings.cameraPreset = MBCameraPreset.presetPhoto
        
        let overlayViewController = CustomOverlayViewController.init(recognizerCollection: self.recognizerCollection!,
                                                                     cameraSettings: settings.cameraSettings)
        overlayViewController.delegate = self
        self.overlayViewController = overlayViewController
        
        let recognizerController = MBViewControllerFactory.recognizerRunnerViewController(withOverlayViewController: overlayViewController)!
        recognizerController.view.frame = frame
        controller.view.addSubview(recognizerController.view)
        controller.addChild(recognizerController)
        recognizerController.didMove(toParent: controller)
    }
    
    func onClose() {
        self.channel.invokeMethod("onClose", arguments: nil)
    }
    
    func onError(error: Error) {
        print("\(error)")
        self.channel.invokeMethod("onError", arguments: error.localizedDescription)
    }
    
    func onFinishScanning(results:  [MBRecognizer]) {
        print("onFinishScanning: \(results)")
        self.resulstHandler.add(results)
        //        let data = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
        //        let arguments = data == nil ? nil : String(data: data!, encoding: .utf8)
        //        self.channel.invokeMethod("onFinishScanning", arguments: arguments)
    }
    
    func onFirstSideScanned() {
        self.channel.invokeMethod("onFirstSideScanned", arguments: nil)
    }
    
    func onDetectionStatusUpdated(_ status: MBDetectionStatus) {
        print("onDetectionStatusUpdated: \(status)")
        self.statusHandler.add(status)
        
        //        let encodedStatus: String = {switch status {
        //        case .cameraAtAngle:
        //            return "CAMERA_AT_ANGLE"
        //        case .fail:
        //            return "FAIL"
        //        case .success:
        //            return "SUCCESS"
        //        case .cameraTooHigh:
        //            return "CAMERA_TOO_HIGH"
        //        case .fallbackSuccess:
        //            return "FALLBACK_SUCCESS"
        //        case .partialForm:
        //            return "PARTIAL_OBJECT"
        //        case .cameraTooNear:
        //            return "CAMERA_TOO_NEAR"
        //        case .documentTooCloseToEdge:
        //            return "DOCUMENT_TOO_CLOSE_TO_EDGE"
        //        default:
        //            return ""
        //        }}()
        //        if encodedStatus.isEmpty {
        //            return
        //        }
        //
        //        self.channel.invokeMethod("onDetectionStatusUpdate", arguments: "{\"detectionStatus\": \"\(encodedStatus)\"}")
    }
    
    
    
    
    
    private func methodHandler(call: FlutterMethodCall, result: @escaping FlutterResult ){
        print(call.method)
        switch (call.method) {
        case "pauseScanning":
            self.overlayViewController?.pauseScanning()
            result(nil)
        case "resumeScanningAndResetState":
            self.overlayViewController?.resumeScanningAndResetState(call.arguments as! Bool)
            result(nil)
        default:
            result(FlutterError(code: "Unimplemented", message: "\(call.method) not implemented.", details: nil))
        }
        
    }
    
    
}

protocol CustomOverlayViewControllerDelegate {
    func onFinishScanning(results:  [MBRecognizer] )
    func onFirstSideScanned()
    func onDetectionStatusUpdated(_ status: MBDetectionStatus)
    func onClose()
    func onError(error: Error)
}

class CustomOverlayViewController : MBCustomOverlayViewController,
                                    MBScanningRecognizerRunnerViewControllerDelegate,
                                    MBFirstSideFinishedRecognizerRunnerViewControllerDelegate,
                                    MBDetectionRecognizerRunnerViewControllerDelegate, MBRecognizerRunnerViewControllerDelegate {
    var delegate: CustomOverlayViewControllerDelegate?
    
    func recognizerRunnerViewControllerUnauthorizedCamera(_ recognizerRunnerViewController: UIViewController & MBRecognizerRunnerViewController) {}
    
    func recognizerRunnerViewController(_ recognizerRunnerViewController: UIViewController & MBRecognizerRunnerViewController,
                                        didFindError error: Error) {
        DispatchQueue.main.async {
            self.delegate?.onError(error: error)
        }
    }
    
    func recognizerRunnerViewControllerDidClose(_ recognizerRunnerViewController: UIViewController & MBRecognizerRunnerViewController) {
        DispatchQueue.main.async {
            self.delegate?.onClose()
        }
    }
    
    func recognizerRunnerViewControllerWillPresentHelp(_ recognizerRunnerViewController: UIViewController & MBRecognizerRunnerViewController) {}
    
    func recognizerRunnerViewControllerDidResumeScanning(_ recognizerRunnerViewController: UIViewController & MBRecognizerRunnerViewController) {}
    
    func recognizerRunnerViewControllerDidStopScanning(_ recognizerRunnerViewController: UIViewController & MBRecognizerRunnerViewController) {}
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(recognizerCollection: MBRecognizerCollection, cameraSettings: MBCameraSettings) {
        super.init(recognizerCollection: recognizerCollection, cameraSettings: cameraSettings)
        self.scanningRecognizerRunnerViewControllerDelegate = self
        self.recognizerRunnerViewControllerDelegate = self
        self.metadataDelegates.detectionRecognizerRunnerViewControllerDelegate = self
        self.metadataDelegates.firstSideFinishedRecognizerRunnerViewControllerDelegate = self
    }
    
    func recognizerRunnerViewControllerDidFinishRecognition(ofFirstSide recognizerRunnerViewController: UIViewController & MBRecognizerRunnerViewController) {
        DispatchQueue.main.async {
            self.delegate?.onFirstSideScanned()
        }
    }
    
    func recognizerRunnerViewController(_ recognizerRunnerViewController: UIViewController & MBRecognizerRunnerViewController,
                                        didFinishDetectionWithDisplayableQuad displayableQuad: MBDisplayableQuadDetection) {
        self.delegate?.onDetectionStatusUpdated(displayableQuad.detectionStatus)
    }
    
    func recognizerRunnerViewControllerDidFinishScanning(_ recognizerRunnerViewController: UIViewController & MBRecognizerRunnerViewController,
                                                         state: MBRecognizerResultState) {
        recognizerRunnerViewController.pauseScanning()
        self.delegate?.onFinishScanning(results:  self.recognizerCollection.recognizerList)
        
    }

    func pauseScanning() { recognizerRunnerViewController?.pauseScanning() }
    
    func resumeScanningAndResetState(_ resetState: Bool) {
        DispatchQueue.main.async {
            self.recognizerRunnerViewController?.resumeScanningAndResetState(resetState)
        }
        
    }
    
}
