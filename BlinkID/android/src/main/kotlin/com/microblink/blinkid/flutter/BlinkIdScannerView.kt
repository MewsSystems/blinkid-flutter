package com.microblink.blinkid.flutter

import android.annotation.SuppressLint
import android.content.Context
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.microblink.blinkid.core.BlinkIdSdk
import com.microblink.blinkid.core.image.ImageRotation
import com.microblink.blinkid.core.image.InputImage
import com.microblink.blinkid.core.result.ScanningStatus
import com.microblink.blinkid.core.session.BlinkIdScanningSession
import com.microblink.blinkid.core.session.DetectionStatus
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.util.concurrent.Executors

@SuppressLint("ViewConstructor")
class BlinkIdScannerView(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    private val creationParams: Map<String, Any>,
    private val sdkProvider: () -> BlinkIdSdk?,
) : PlatformView, LifecycleOwner {

    private val previewView = PreviewView(context).apply {
        // TextureView composites into the Flutter render tree (TLHC-compatible).
        // Default SurfaceView creates a separate window surface that renders above all Flutter widgets.
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val scope = CoroutineScope(Dispatchers.Main)

    private val methodChannel = MethodChannel(
        messenger,
        "com.microblink.blinkid.flutter/scanner/$viewId",
    )
    private val eventChannel = EventChannel(
        messenger,
        "com.microblink.blinkid.flutter/scanner/$viewId/guidance",
    )

    private var guidanceEventSink: EventChannel.EventSink? = null
    private var scanningSession: BlinkIdScanningSession? = null
    private var isScanning = false
    private val analysisExecutor = Executors.newSingleThreadExecutor()

    override val lifecycle: Lifecycle get() = lifecycleRegistry

    init {
        lifecycleRegistry.currentState = Lifecycle.State.CREATED

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                guidanceEventSink = sink
            }
            override fun onCancel(arguments: Any?) {
                guidanceEventSink = null
            }
        })

        methodChannel.setMethodCallHandler { call, result -> handleMethodCall(call, result) }

        setupCamera()
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan" -> startScan(result)
            "cancelScan" -> {
                isScanning = false
                scanningSession = null
                result.success(null)
            }
            "resumeAfterFlip" -> {
                // Flip animation completed on Flutter side; re-enable frame processing.
                isScanning = true
                result.success(null)
            }
            "dispose" -> {
                dispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startScan(result: MethodChannel.Result) {
        val sdk = sdkProvider()
        if (sdk == null) {
            result.error("blinkid_error", "SDK not initialized", null)
            return
        }

        scope.launch {
            val sessionSettingsMap = creationParams["sessionSettings"] as? Map<*, *>
            @Suppress("UNCHECKED_CAST")
            val sessionResult = sdk.createScanningSession(
                BlinkIdDeserializationUtils.deserializeBlinkIdSessionSettings(
                    sessionSettingsMap as? Map<String, Any>,
                    false,
                )
            )
            if (sessionResult.isFailure) {
                result.error("blinkid_error", sessionResult.exceptionOrNull()?.message, null)
                return@launch
            }
            scanningSession = sessionResult.getOrThrow()
            isScanning = true
            result.success(null)
        }
    }

    private fun setupCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val cameraProvider = try {
                cameraProviderFuture.get()
            } catch (e: Exception) {
                scope.launch {
                    methodChannel.invokeMethod("onScanError", "Camera unavailable: ${e.message}")
                }
                return@addListener
            }

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()

            imageAnalysis.setAnalyzer(analysisExecutor) { imageProxy ->
                if (!isScanning) {
                    imageProxy.close()
                    return@setAnalyzer
                }
                val session = scanningSession ?: run { imageProxy.close(); return@setAnalyzer }

                val imageRotation = when (imageProxy.imageInfo.rotationDegrees) {
                    90 -> ImageRotation.Rotation90
                    180 -> ImageRotation.Rotation180
                    270 -> ImageRotation.Rotation270
                    else -> ImageRotation.Rotation0
                }
                val inputImage = InputImage.createFromCameraXImageProxy(imageProxy, imageRotation)
                val processResult = runBlocking { session.process(inputImage) }

                if (processResult.isFailure) {
                    android.util.Log.e("BlinkIdScannerView", "process() failed: ${processResult.exceptionOrNull()}")
                } else if (processResult.isSuccess) {
                    val frameResult = processResult.getOrNull()!!
                    val detectionStatus = frameResult.inputImageAnalysisResult.documentDetectionStatus
                    val scanningStatus = runBlocking { session.getScanningStatus() }

                    when (scanningStatus) {
                        ScanningStatus.DocumentScanned -> {
                            isScanning = false
                            scope.launch {
                                val scanResult = session.getResult(null)
                                if (scanResult.isSuccess) {
                                    val json = BlinkIdSerializationUtils.serializeBlinkIdScanningResult(
                                        scanResult.getOrNull()
                                    )
                                    methodChannel.invokeMethod("onScanResult", json)
                                } else {
                                    methodChannel.invokeMethod(
                                        "onScanError",
                                        scanResult.exceptionOrNull()?.message ?: "Scan failed",
                                    )
                                }
                                scanningSession = null
                            }
                        }
                        ScanningStatus.SideScanned -> {
                            // First side done; pause until Flutter calls resumeAfterFlip.
                            isScanning = false
                            scope.launch { guidanceEventSink?.success("flipDocument") }
                        }
                        else -> {
                            val guidance = detectionStatus.toGuidanceString()
                            scope.launch { guidanceEventSink?.success(guidance) }
                        }
                    }
                }
                imageProxy.close()
            }

            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                this,
                CameraSelector.DEFAULT_BACK_CAMERA,
                preview,
                imageAnalysis,
            )
        }, ContextCompat.getMainExecutor(context))
    }

    override fun getView(): View = previewView

    override fun dispose() {
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        isScanning = false
        scanningSession = null
        analysisExecutor.shutdown()
        scope.cancel()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}

private fun DetectionStatus.toGuidanceString(): String = when (this) {
    DetectionStatus.CameraTooFar -> "tooFar"
    DetectionStatus.CameraTooClose -> "tooClose"
    DetectionStatus.DocumentTooCloseToCameraEdge -> "tooCloseToEdge"
    DetectionStatus.CameraAngleTooSteep -> "tilted"
    DetectionStatus.DocumentPartiallyVisible -> "notFullyVisible"
    DetectionStatus.Success, DetectionStatus.Failed -> "searching"
}
