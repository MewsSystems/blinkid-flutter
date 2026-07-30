import AVFoundation
import BlinkID
import Flutter
import UIKit

public class BlinkIdScannerView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private let viewId: Int64
    private let creationParams: [String: Any]
    private let sdkProvider: () -> AnyObject?

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var guidanceEventSink: FlutterEventSink?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var blinkIdSession: BlinkIDScanningSession?
    private var isScanning = false
    private var isProcessingResult = false

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        creationParams: [String: Any],
        sdkProvider: @escaping () -> AnyObject?,
    ) {
        self.viewId = viewId
        self.creationParams = creationParams
        self.sdkProvider = sdkProvider
        self.containerView = UIView(frame: frame)

        methodChannel = FlutterMethodChannel(
            name: "com.microblink.blinkid.flutter/scanner/\(viewId)",
            binaryMessenger: messenger,
        )
        eventChannel = FlutterEventChannel(
            name: "com.microblink.blinkid.flutter/scanner/\(viewId)/guidance",
            binaryMessenger: messenger,
        )

        super.init()

        eventChannel.setStreamHandler(self)
        methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }

        setupCamera()
    }

    public func view() -> UIView { containerView }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startScan":
            startScan(result: result)
        case "cancelScan":
            isScanning = false
            blinkIdSession = nil
            result(nil)
        case "dispose":
            teardown()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startScan(result: @escaping FlutterResult) {
        guard let sdk = sdkProvider() as? BlinkIDSdk else {
            result(FlutterError(code: "blinkid_error", message: "SDK not initialized", details: nil))
            return
        }
        guard let sessionSettingsDict = creationParams["sessionSettings"] as? [String: Any] else {
            result(FlutterError(code: "blinkid_error", message: "Missing sessionSettings", details: nil))
            return
        }
        Task {
            do {
                let sessionSettings = BlinkIdDeserializationUtils.deserializeBlinkIdSessionSettings(
                    sessionSettingsDict,
                    isFromDirectApi: false,
                )
                let session = try await sdk.createScanningSession(sessionSettings: sessionSettings)
                self.blinkIdSession = session
                self.isScanning = true
                result(nil)
            } catch {
                result(FlutterError(code: "blinkid_error", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "com.microblink.blinkid.scanner.\(viewId)"),
        )

        guard session.canAddInput(input), session.canAddOutput(output) else { return }
        session.addInput(input)
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            connection.videoRotationAngle = 90
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = containerView.bounds
        containerView.layer.addSublayer(preview)
        self.previewLayer = preview
        self.captureSession = session

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func teardown() {
        isScanning = false
        blinkIdSession = nil
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
    }
}

extension BlinkIdScannerView: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection,
    ) {
        guard isScanning, !isProcessingResult, let session = blinkIdSession else { return }

        let inputImage = InputImage(
            cameraFrame: CameraFrame(buffer: sampleBuffer, orientation: .portrait),
        )

        Task {
            do {
                let frameResult = try await session.process(inputImage: inputImage)
                await handleFrameResult(frameResult, session: session)
            } catch {
                // non-fatal frame error; continue scanning
            }
        }
    }

    @MainActor
    private func handleFrameResult(_ frameResult: BlinkIDFrameProcessResult, session: BlinkIDScanningSession) async {
        // Emit guidance from detection status
        if let status = frameResult.detectionStatus {
            guidanceEventSink?(status.guidanceString)
        }

        // Scanning complete when frameResult signals done
        guard frameResult.resultCompletionStatus == .complete, !isProcessingResult else { return }
        isProcessingResult = true
        isScanning = false

        do {
            let scanResult = try await session.getResult(redactionSettings: nil)
            let json = BlinkIdSerializationUtils.serializeBlinkIdScanningResult(scanResult)
            methodChannel.invokeMethod("onScanResult", arguments: json)
        } catch {
            methodChannel.invokeMethod("onScanError", arguments: error.localizedDescription)
        }
        blinkIdSession = nil
        isProcessingResult = false
    }
}

extension BlinkIdScannerView: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        guidanceEventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        guidanceEventSink = nil
        return nil
    }
}

private extension BlinkIDDetectionStatus {
    var guidanceString: String {
        switch self {
        case .tooFar: return "tooFar"
        case .tooClose: return "tooClose"
        case .cameraTiltedTooMuch: return "tilted"
        case .holdStill: return "holdStill"
        case .flipDocument: return "flipDocument"
        default: return "searching"
        }
    }
}
