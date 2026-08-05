package com.microblink.blinkid.flutter

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.microblink.blinkid.core.BlinkIdSdk
import com.microblink.blinkid.core.image.InputImage
import com.microblink.blinkid.core.result.ImageAnalysisDetectionStatus
import com.microblink.blinkid.core.result.ProcessingStatus
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
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors

@SuppressLint("ViewConstructor")
class BlinkIdScannerView(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    private val creationParams: Map<String, Any>,
    private val sdkProvider: () -> BlinkIdSdk?,
    private val requestCameraPermission: (Activity, (Boolean) -> Unit) -> Unit,
) : PlatformView,
    LifecycleOwner {
    private val previewView =
        PreviewView(context).apply {
            // TextureView composites into the Flutter render tree (TLHC-compatible).
            // Default SurfaceView creates a separate window surface that renders above all Flutter widgets.
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        }
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val scope = CoroutineScope(Dispatchers.Main)

    private val methodChannel =
        MethodChannel(
            messenger,
            "com.microblink.blinkid.flutter/scanner/$viewId",
        )
    private val eventChannel =
        EventChannel(
            messenger,
            "com.microblink.blinkid.flutter/scanner/$viewId/guidance",
        )

    private var guidanceEventSink: EventChannel.EventSink? = null
    @Volatile private var debugLoggingEnabled = false
    @Volatile private var scanningSession: BlinkIdScanningSession? = null
    @Volatile private var isScanning = false
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private var pendingStartResult: MethodChannel.Result? = null
    @Volatile private var preferredCameraOverride: String? = null

    override val lifecycle: Lifecycle get() = lifecycleRegistry

    init {
        lifecycleRegistry.currentState = Lifecycle.State.CREATED

        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    sink: EventChannel.EventSink?,
                ) {
                    guidanceEventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    guidanceEventSink = null
                }
            },
        )

        methodChannel.setMethodCallHandler { call, result -> handleMethodCall(call, result) }

        setupCamera()
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
    }

    private fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "startScan" -> {
                startScan(result)
            }

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

            "retryCamera" -> {
                scope.launch {
                    withContext(analysisExecutor.asCoroutineDispatcher()) {}
                    setupCamera()
                }
                result.success(null)
            }

            "switchCamera" -> {
                isScanning = false
                scanningSession = null
                preferredCameraOverride = call.arguments as? String
                scope.launch {
                    // Drain any in-flight analyzer frame, then let BlinkID's
                    // ProcessingQueue settle before unbindAll().
                    withContext(analysisExecutor.asCoroutineDispatcher()) {}
                    delay(500L)
                    setupCamera()
                }
                result.success(null)
            }

            "setDebugLogging" -> {
                debugLoggingEnabled = call.arguments as? Boolean ?: false
                result.success(null)
            }

            "dispose" -> {
                dispose()
                // Dart sends 'cancel' before 'dispose' on the same binary-messenger
                // queue, so by the time we reach here the EventChannel 'onCancel'
                // has already fired and guidanceEventSink is null.  Clearing the
                // handler now releases the StreamHandler→this strong reference
                // without any risk of a MissingPluginException.
                eventChannel.setStreamHandler(null)
                result.success(null)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startScan(result: MethodChannel.Result) {
        val sdk = sdkProvider()
        if (sdk == null) {
            result.error("blinkid_error", "SDK not initialized", null)
            return
        }
        if (pendingStartResult != null) {
            result.error("blinkid_error", "Scan already starting", null)
            return
        }
        pendingStartResult = result
        scope.launch {
            val sessionSettingsMap = creationParams["sessionSettings"] as? Map<*, *>

            @Suppress("UNCHECKED_CAST")
            val sessionResult =
                sdk.createScanningSession(
                    BlinkIdDeserializationUtils.deserializeBlinkIdSessionSettings(
                        sessionSettingsMap as? Map<String, Any>,
                        false,
                    ),
                )
            val pending = pendingStartResult ?: return@launch
            pendingStartResult = null
            if (sessionResult.isFailure) {
                pending.error("blinkid_error", sessionResult.exceptionOrNull()?.message, null)
                return@launch
            }
            scanningSession = sessionResult.getOrThrow()
            isScanning = true
            pending.success(null)
        }
    }

    // Returns the Activity wrapping this PlatformView's context, or null if unavailable.
    private fun requireActivity(): Activity? {
        var ctx: Context = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) return ctx
            ctx = ctx.baseContext
        }
        return null
    }

    private fun setupCamera() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            performCameraSetup()
            return
        }
        val activity = requireActivity()
        if (activity == null) {
            // No activity context to show dialog — notify Dart directly.
            invokePermissionRequired(permanentlyDenied = false)
            return
        }
        // Show the system permission dialog. Result dispatched via the plugin's
        // RequestPermissionsResultListener → our callback.
        requestCameraPermission(activity) { granted ->
            if (granted) {
                performCameraSetup()
            } else {
                // After denial shouldShowRequestPermissionRationale returns true for
                // soft deny, false for "Never ask again" — more reliable than checking
                // before the request (which is always false on a fresh install).
                val permanentlyDenied =
                    !ActivityCompat.shouldShowRequestPermissionRationale(
                        activity,
                        Manifest.permission.CAMERA,
                    )
                invokePermissionRequired(permanentlyDenied)
            }
        }
    }

    private fun invokePermissionRequired(permanentlyDenied: Boolean) {
        scope.launch {
            methodChannel.invokeMethod(
                "onPermissionRequired",
                mapOf("permanentlyDenied" to permanentlyDenied),
            )
        }
    }

    private fun performCameraSetup() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val cameraProvider =
                try {
                    cameraProviderFuture.get()
                } catch (e: Exception) {
                    scope.launch {
                        methodChannel.invokeMethod("onScanError", "Camera unavailable: ${e.message}")
                    }
                    return@addListener
                }

            val preview =
                Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }

            val imageAnalysis =
                ImageAnalysis
                    .Builder()
                    .setResolutionSelector(
                        ResolutionSelector
                            .Builder()
                            .setResolutionStrategy(ResolutionStrategy.HIGHEST_AVAILABLE_STRATEGY)
                            .build(),
                    ).build()

            imageAnalysis.setAnalyzer(analysisExecutor) { imageProxy ->
                if (!isScanning) {
                    imageProxy.close()
                    return@setAnalyzer
                }
                val session =
                    scanningSession ?: run {
                        imageProxy.close()
                        return@setAnalyzer
                    }

                try {
                    val inputImage = InputImage.createFromCameraXImageProxy(imageProxy)
                    val processResult = runBlocking { session.process(inputImage) }

                    if (processResult.isFailure) {
                        val msg = "process() failed: ${processResult.exceptionOrNull()}"
                        scope.launch { if (debugLoggingEnabled) methodChannel.invokeMethod("onDebugLog", msg) }
                    } else if (processResult.isSuccess) {
                        val frameResult = processResult.getOrNull()!!
                        val detectionStatus = frameResult.inputImageAnalysisResult.documentDetectionStatus
                        val scanningStatus = runBlocking { session.getScanningStatus() }

                        when (scanningStatus) {
                            ScanningStatus.DocumentScanned -> {
                                isScanning = false
                                scope.launch {
                                    if (scanningSession !== session) return@launch
                                    if (debugLoggingEnabled) methodChannel.invokeMethod("onDebugLog", "DocumentScanned — calling getResult()")
                                    // Signal Flutter immediately so it can show a spinner while
                                    // getResult() serializes (potentially large) image data.
                                    methodChannel.invokeMethod("onDocumentScanned", null)
                                    val scanResult = withContext(Dispatchers.Default) { session.getResult(null) }
                                    if (scanningSession !== session) return@launch
                                    if (scanResult.isSuccess) {
                                        val jsonString =
                                            withContext(Dispatchers.Default) {
                                                BlinkIdSerializationUtils.serializeBlinkIdScanningResult(
                                                    scanResult.getOrNull(),
                                                )
                                            }
                                        methodChannel.invokeMethod("onScanResult", jsonString)
                                    } else {
                                        val err = scanResult.exceptionOrNull()?.message ?: "Scan failed"
                                        if (debugLoggingEnabled) methodChannel.invokeMethod("onDebugLog", "getResult() failed: $err")
                                        methodChannel.invokeMethod("onScanError", err)
                                    }
                                    scanningSession = null
                                }
                            }

                            ScanningStatus.SideScanned -> {
                                // First side done; pause until Flutter calls resumeAfterFlip.
                                isScanning = false
                                scope.launch {
                                    if (scanningSession !== session) return@launch
                                    if (debugLoggingEnabled) methodChannel.invokeMethod("onDebugLog", "SideScanned — pausing for flip")
                                    guidanceEventSink?.success("flipDocument")
                                }
                            }

                            else -> {
                                val ia = frameResult.inputImageAnalysisResult
                                val guidance = when {
                                    ia.processingStatus == ProcessingStatus.ScanningWrongSide -> "wrongSide"
                                    ia.blurDetectionStatus == ImageAnalysisDetectionStatus.Detected -> "blur"
                                    ia.glareDetectionStatus == ImageAnalysisDetectionStatus.Detected -> "glare"
                                    else -> detectionStatus.toGuidanceString()
                                }
                                scope.launch {
                                    if (scanningSession !== session) return@launch
                                    guidanceEventSink?.success(guidance)
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    scope.launch {
                        if (debugLoggingEnabled) methodChannel.invokeMethod("onDebugLog", "Analyzer error: ${e.message}")
                    }
                } finally {
                    imageProxy.close()
                }
            }

            try {
                val preferred = preferredCameraOverride ?: creationParams["preferredCamera"] as? String
                val cameraSelector = resolveCameraSelector(preferred, cameraProvider)
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageAnalysis)
            } catch (e: Exception) {
                scope.launch { methodChannel.invokeMethod("onScanError", "Camera bind failed: ${e.message}") }
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun resolveCameraSelector(
        preferred: String?,
        provider: ProcessCameraProvider?,
    ): CameraSelector {
        if (preferred == "front" && provider?.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA) == true) {
            return CameraSelector.DEFAULT_FRONT_CAMERA
        }
        return CameraSelector.DEFAULT_BACK_CAMERA
    }

    override fun getView(): View = previewView

    override fun dispose() {
        pendingStartResult?.error("blinkid_error", "Scanner disposed", null)
        pendingStartResult = null
        isScanning = false
        scanningSession = null
        // Drain any in-flight analyzer frame before CameraX unbinds.
        try { analysisExecutor.submit {}.get(500L, java.util.concurrent.TimeUnit.MILLISECONDS) } catch (_: Exception) {}
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        analysisExecutor.shutdown()
        scope.cancel()
        methodChannel.setMethodCallHandler(null)
        // Null the sink immediately so no guidance events are emitted after
        // disposal (covers the engine-direct PlatformView.dispose() path).
        // The StreamHandler itself is unregistered in the "dispose" method-
        // channel handler, which runs after Dart's 'cancel' has already arrived.
        guidanceEventSink = null
    }
}

private fun DetectionStatus.toGuidanceString(): String =
    when (this) {
        DetectionStatus.CameraTooFar -> "tooFar"
        DetectionStatus.CameraTooClose -> "tooClose"
        DetectionStatus.DocumentTooCloseToCameraEdge -> "tooCloseToEdge"
        DetectionStatus.CameraAngleTooSteep -> "tilted"
        DetectionStatus.DocumentPartiallyVisible -> "notFullyVisible"
        DetectionStatus.Success, DetectionStatus.Failed -> "searching"
    }
