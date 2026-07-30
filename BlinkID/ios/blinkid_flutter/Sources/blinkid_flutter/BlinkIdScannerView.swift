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
    // Guards against multiple completion calls from in-flight Tasks.
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
        case "resumeAfterFlip":
            isScanning = true
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
                // process() is Void-returning on iOS; guidance comes via session status.
                try await session.process(inputImage: inputImage)

                // TODO: Replace with session.getScanningStatus() equivalent once
                // the iOS SDK exposes it. For now poll getResult() to detect completion.
                // getResult() throws when scanning is still in progress.
                await checkScanningStatus(session: session)
            } catch {
                // Non-fatal frame error; continue scanning.
            }
        }
    }

    @MainActor
    private func checkScanningStatus(session: BlinkIDScanningSession) async {
        // Attempt to retrieve guidance from session's last detection status.
        if let detectionStatus = session.lastDetectionStatus {
            let guidance = detectionStatus.guidanceString
            guidanceEventSink?(guidance)
        }

        // Check if a scanning side completed or the full scan is done.
        // getResult() is the current best signal for iOS — it succeeds only when
        // enough data is captured. Replace with a dedicated status API if exposed.
        guard !isProcessingResult else { return }

        let resultAttempt = await session.getResult(redactionSettings: nil)
        switch resultAttempt {
        case .success(let scanResult) where scanResult != nil:
            // Full scan complete.
            isProcessingResult = true
            isScanning = false
            let json = BlinkIdSerializationUtils.serializeBlinkIdScanningResult(scanResult)
            methodChannel.invokeMethod("onScanResult", arguments: json)
            blinkIdSession = nil
            isProcessingResult = false

        case .success:
            // getResult succeeded but no data yet — keep scanning.
            break

        case .failure:
            // Still scanning — expected, not an error.
            break
        }
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

// MARK: - DetectionStatus → guidance string
// TODO: Verify these enum case names against the compiled BlinkID.xcframework.
// Android verified cases: CameraTooFar, CameraTooClose, DocumentTooCloseToCameraEdge,
// CameraAngleTooSteep, DocumentPartiallyVisible, Success, Failed.
private extension BlinkIDDetectionStatus {
    var guidanceString: String {
        switch self {
        case .cameraTooFar: return "tooFar"
        case .cameraTooClose: return "tooClose"
        case .documentTooCloseToCameraEdge: return "tooCloseToEdge"
        case .cameraAngleTooSteep: return "tilted"
        case .documentPartiallyVisible: return "notFullyVisible"
        default: return "searching"
        }
    }
}
