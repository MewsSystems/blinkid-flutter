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
import com.microblink.blinkid.core.image.InputImage
import com.microblink.blinkid.core.session.BlinkIdProcessResult
import com.microblink.blinkid.core.session.BlinkIdScanningSession
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.concurrent.Executors

@SuppressLint("ViewConstructor")
class BlinkIdScannerView(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    private val creationParams: Map<String, Any>,
    private val sdkProvider: () -> BlinkIdSdk?,
) : PlatformView, LifecycleOwner {

    private val previewView = PreviewView(context)
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
                BlinkidDeserializationUtils.deserializeBlinkIdSessionSettings(
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

                val rotation = imageProxy.imageInfo.rotationDegrees
                val inputImage = InputImage.createFromCameraXImageProxy(imageProxy, rotation)
                val processResult = session.process(inputImage)

                if (processResult.isSuccess) {
                    val frameResult = processResult.getOrNull()
                    when (frameResult) {
                        is BlinkIdProcessResult.Detection -> {
                            val guidance = frameResult.detectionStatus?.toGuidanceString() ?: "searching"
                            scope.launch {
                                guidanceEventSink?.success(guidance)
                                // Pause frame processing when flip is needed; Flutter side
                                // calls resumeAfterFlip when its animation completes.
                                if (guidance == "flipDocument") {
                                    isScanning = false
                                }
                            }
                        }
                        is BlinkIdProcessResult.Complete -> {
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
                        else -> {}
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

private fun Any.toGuidanceString(): String = when (toString()) {
    "TOO_FAR", "TooFar" -> "tooFar"
    "TOO_CLOSE", "TooClose" -> "tooClose"
    "DOCUMENT_TOO_CLOSE_TO_FRAME_EDGE" -> "tooCloseToEdge"
    "CAMERA_ANGLE_TOO_STEEP", "CameraAngleTooSteep" -> "tilted"
    "HOLD_STILL", "HoldStill" -> "holdStill"
    "FLIP_DOCUMENT", "FlipDocument" -> "flipDocument"
    "BLUR_DETECTED", "BlurDetected" -> "blur"
    "GLARE_DETECTED", "GlareDetected" -> "glare"
    "DOCUMENT_NOT_FULLY_VISIBLE", "DocumentNotFullyVisible" -> "notFullyVisible"
    "FACE_PHOTO_NOT_FULLY_VISIBLE", "FacePhotoNotFullyVisible" -> "notFullyVisible"
    "LOW_LIGHTING", "LowLighting", "INCREASE_LIGHTING_INTENSITY" -> "lowLight"
    "TOO_MUCH_LIGHTING", "TooMuchLighting", "DECREASE_LIGHTING_INTENSITY" -> "tooMuchLight"
    else -> "searching"
}
