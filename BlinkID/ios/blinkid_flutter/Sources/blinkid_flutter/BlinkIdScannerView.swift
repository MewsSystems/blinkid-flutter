import AVFoundation
import BlinkID
import Flutter
import UIKit

private final class CameraContainerView: UIView {
    weak var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

public class BlinkIdScannerView: NSObject, FlutterPlatformView {
    private let containerView: CameraContainerView
    private let viewId: Int64
    private let creationParams: [String: Any]
    private let sdkProvider: () -> AnyObject?

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var guidanceEventSink: FlutterEventSink?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var blinkIdSession: BlinkIDSession?
    nonisolated(unsafe) private var isScanning = false
    // Guards against multiple completion calls from in-flight Tasks.
    nonisolated(unsafe) private var isProcessingResult = false
    // Only one @ProcessingActor Task in-flight at a time. Without this, captureOutput
    // spawns a Task per frame (30fps) faster than @ProcessingActor can consume them, building
    // a ~300-frame backlog that makes the scan take 10+ seconds.
    nonisolated(unsafe) private var isProcessingFrame = false
    nonisolated(unsafe) private var currentFrameOrientation: CameraFrameVideoOrientation = .portrait
    private var cameraSetupFailed = false

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
        self.containerView = CameraContainerView(frame: frame)

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

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil,
        )

        setupCamera()
    }

    public func view() -> UIView { containerView }

    @objc private func deviceOrientationDidChange() {
        updateVideoOrientation()
    }

    private func updateVideoOrientation() {
        let deviceOrientation = UIDevice.current.orientation
        guard deviceOrientation.isValidInterfaceOrientation else { return }

        currentFrameOrientation = deviceOrientation.cameraFrameOrientation

        if #available(iOS 17.0, *) {
            let angle = deviceOrientation.videoRotationAngle
            videoOutput?.connection(with: .video)?.videoRotationAngle = angle
            previewLayer?.connection?.videoRotationAngle = angle
        } else {
            let avOrientation = deviceOrientation.avCaptureOrientation
            videoOutput?.connection(with: .video)?.videoOrientation = avOrientation
            previewLayer?.connection?.videoOrientation = avOrientation
        }
    }

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
        if cameraSetupFailed {
            result(FlutterError(code: "blinkid_error", message: "Camera unavailable", details: nil))
            return
        }
        guard let sdk = sdkProvider() as? BlinkIDSdk else {
            result(FlutterError(code: "blinkid_error", message: "SDK not initialized", details: nil))
            return
        }
        guard let sessionSettingsDict = creationParams["sessionSettings"] as? [String: Any] else {
            result(FlutterError(code: "blinkid_error", message: "Missing sessionSettings", details: nil))
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
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
        else {
            cameraSetupFailed = true
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "com.microblink.blinkid.scanner.\(viewId)"),
        )

        guard session.canAddInput(input), session.canAddOutput(output) else {
            cameraSetupFailed = true
            return
        }
        session.addInput(input)
        session.addOutput(output)
        self.videoOutput = output

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = containerView.bounds
        containerView.layer.addSublayer(preview)
        containerView.previewLayer = preview
        self.previewLayer = preview
        self.captureSession = session

        // Apply initial orientation after connections exist.
        updateVideoOrientation()

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func teardown() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
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
        guard isScanning, !isProcessingResult, !isProcessingFrame, let session = blinkIdSession else { return }
        isProcessingFrame = true

        let frameOrientation = currentFrameOrientation
        let inputImage = InputImage(
            cameraFrame: CameraFrame(buffer: sampleBuffer, orientation: frameOrientation),
        )

        Task { @ProcessingActor [weak self] in
            defer { self?.isProcessingFrame = false }
            guard let self else { return }
            do {
                let frameResult = try await session.process(inputImage: inputImage)

                if let sessionErr = frameResult.sessionError {
                    print("[BlinkIdScannerView] process sessionError: \(sessionErr)")
                }

                let processingStatus = frameResult.processResult?.inputImageAnalysisResult.processingStatus
                if processingStatus == .scanningWrongSide {
                    await MainActor.run { self.guidanceEventSink?("wrongSide") }
                } else if let detectionStatus = frameResult.processResult?.inputImageAnalysisResult.documentDetectionStatus {
                    let guidance = detectionStatus.guidanceString
                    await MainActor.run { self.guidanceEventSink?(guidance) }
                }

                let status = session.getScanningStatus()
                print("[BlinkIdScannerView] getScanningStatus: \(status)")

                switch status {
                case .sideScanned:
                    print("[BlinkIdScannerView] sideScanned — pausing for flip")
                    self.isScanning = false
                    await MainActor.run { self.guidanceEventSink?("flipDocument") }

                case .documentScanned:
                    print("[BlinkIdScannerView] documentScanned — calling getResult()")
                    guard !self.isProcessingResult else {
                        print("[BlinkIdScannerView] already processing result, skipping")
                        return
                    }
                    self.isProcessingResult = true
                    self.isScanning = false
                    // Signal Flutter immediately so it can show a spinner while
                    // getResult() serializes (potentially large) image data.
                    await MainActor.run { self.methodChannel.invokeMethod("onDocumentScanned", arguments: nil) }
                    let scanResult = session.getResult(redactionSettings: nil)
                    print("[BlinkIdScannerView] getResult() returned, serializing")
                    let jsonString = BlinkIdSerializationUtils.serializeBlinkIdScanningResult(scanResult)
                    let resultDict: [String: Any]? = jsonString.flatMap { str in
                        guard let data = str.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { return nil }
                        return obj
                    }
                    await MainActor.run {
                        print("[BlinkIdScannerView] invoking onScanResult on channel")
                        self.methodChannel.invokeMethod("onScanResult", arguments: resultDict)
                        self.blinkIdSession = nil
                        self.isProcessingResult = false
                    }

                default:
                    break
                }
            } catch {
                print("[BlinkIdScannerView] process() threw: \(error)")
            }
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

// MARK: - Orientation helpers

private extension UIDeviceOrientation {
    var cameraFrameOrientation: CameraFrameVideoOrientation {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft:      return .landscapeLeft
        case .landscapeRight:     return .landscapeRight
        default:                  return .portrait
        }
    }

    // AVCaptureVideoOrientation landscape axes are inverted vs UIDeviceOrientation.
    var avCaptureOrientation: AVCaptureVideoOrientation {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft:      return .landscapeRight
        case .landscapeRight:     return .landscapeLeft
        default:                  return .portrait
        }
    }

    @available(iOS 17.0, *)
    var videoRotationAngle: CGFloat {
        switch self {
        case .portraitUpsideDown: return 270
        case .landscapeLeft:      return 0
        case .landscapeRight:     return 180
        default:                  return 90
        }
    }
}

private extension DetectionStatus {
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
