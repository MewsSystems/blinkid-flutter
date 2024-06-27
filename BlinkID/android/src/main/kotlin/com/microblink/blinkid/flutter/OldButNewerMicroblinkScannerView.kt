package com.microblink.blinkid.flutter

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Rect
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.core.app.ActivityCompat.requestPermissions
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.microblink.blinkid.MicroblinkSDK
import com.microblink.blinkid.entities.recognizers.Recognizer
import com.microblink.blinkid.entities.recognizers.RecognizerBundle
import com.microblink.blinkid.flutter.recognizers.RecognizerSerializers
import com.microblink.blinkid.hardware.camera.CameraType
import com.microblink.blinkid.intent.IntentDataTransferMode
import com.microblink.blinkid.metadata.MetadataCallbacks
import com.microblink.blinkid.metadata.detection.quad.QuadDetectionCallback
import com.microblink.blinkid.metadata.recognition.FirstSideRecognitionCallback
import com.microblink.blinkid.recognition.RecognitionSuccessType
import com.microblink.blinkid.util.RecognizerCompatibility
import com.microblink.blinkid.util.RecognizerCompatibilityStatus
import com.microblink.blinkid.view.CameraEventsListener
import com.microblink.blinkid.view.recognition.RecognizerRunnerView
import com.microblink.blinkid.view.recognition.ScanResultListener
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.platform.PlatformView
import org.json.JSONObject


class MicroblinkScannerRunnerView(
    private val context: Context,
    private val id: Int,
    private val creationParams: MicroblinkCreationParams,
    private val messenger: BinaryMessenger,
    private val activityPluginBinding: ActivityPluginBinding
) : PlatformView, LifecycleOwner, DefaultLifecycleObserver {
    private val PERMISSION_CAMERA_REQUEST_CODE = 42
    private lateinit var mRecognizerRunnerView: RecognizerRunnerView
    private val mRecognizerBundle: RecognizerBundle
    private lateinit var dispatcher: MicroblinkEventDispatcher
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val parentView = FrameLayout(context)
    override val lifecycle: Lifecycle
        get() = lifecycleRegistry
    private val activityLifecycle =
        FlutterLifecycleAdapter.getActivityLifecycle(activityPluginBinding).also { it.addObserver(this) }


    init {
        setLicense(context, creationParams.licenseKey)
        mRecognizerBundle =
            RecognizerSerializers.INSTANCE.deserializeRecognizerCollection(JSONObject(creationParams.recognizerCollection))

        when (val status = RecognizerCompatibility.getRecognizerCompatibilityStatus(context)) {
            RecognizerCompatibilityStatus.RECOGNIZER_SUPPORTED -> {
                Log.e("MicroblinkScannerView", "BlinkID is supported!")
            }

            RecognizerCompatibilityStatus.NO_CAMERA -> {
                Log.e("MicroblinkScannerView", "BlinkID is not supported because there is no camera!")

            }

            RecognizerCompatibilityStatus.PROCESSOR_ARCHITECTURE_NOT_SUPPORTED -> {
                Log.e(
                    "MicroblinkScannerView", "BlinkID is not supported because processor architecture is not supported!"
                )
            }

            else -> {

                Log.e("MicroblinkScannerView", "BlinkID is not supported! Reason: ${status.name}")
            }
        }
        mRecognizerRunnerView = RecognizerRunnerView(context)
        mRecognizerRunnerView.recognizerBundle = mRecognizerBundle
        mRecognizerRunnerView.setScanResultListener(scanResultListener)
        mRecognizerRunnerView.setMetadataCallbacks(metadataCallbacks)
        mRecognizerRunnerView.cameraEventsListener = cameraEventsListener


        mRecognizerRunnerView.setCameraType(
            CameraType.CAMERA_BACKFACE
//            if (creationParams.overlaySettings.useFrontCamera) CameraType.CAMERA_FRONTFACE else CameraType.CAMERA_BACKFACE
        )

//        mRecognizerRunnerView.setOptimizeCameraForNearScan(true)

        dispatcher = MicroblinkEventDispatcher(messenger, id)
        dispatcher.resumeScanningHandler = {
            Log.i("MicroblinkScannerView", "told to resume scanning")
            mRecognizerRunnerView.resumeScanning(true)
        }

        if (mRecognizerRunnerView.parent == null) {
            parentView.addView(
                mRecognizerRunnerView, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        mRecognizerRunnerView.setLifecycle(lifecycle)
    }


    override fun onResume(owner: LifecycleOwner) {
        super.onResume(owner)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME);
    }

    override fun onPause(owner: LifecycleOwner) {
        super.onPause(owner)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE);
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP);
    }

    override fun onFlutterViewAttached(flutterView: View) {
        super.onFlutterViewAttached(flutterView)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE);
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START);
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME);
    }

    override fun dispose() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        activityLifecycle.removeObserver(this)


    }


    private val cameraEventsListener: CameraEventsListener
        get() {
            return object : CameraEventsListener {
                override fun onAutofocusFailed() {
                }

                override fun onAutofocusStarted(p0: Array<out Rect>?) {

                }

                override fun onAutofocusStopped(p0: Array<out Rect>?) {

                }

                override fun onCameraPreviewStarted() {
                    Log.i("MicroblinkScannerView", "Camera preview started")
                }

                override fun onCameraPreviewStopped() {
                    Log.i("MicroblinkScannerView", "Camera preview stopped")
                }

                override fun onError(p0: Throwable) {
                    Log.i("MicroblinkScannerView", "Camera errored: ${p0.message}")
                    dispatcher.reportError(p0)
                }

                override fun onCameraPermissionDenied() {
                    requestPermissions(
                        activityPluginBinding.activity,
                        arrayOf(Manifest.permission.CAMERA),
                        PERMISSION_CAMERA_REQUEST_CODE
                    );
                }
            }
        }

    private val metadataCallbacks: MetadataCallbacks
        get() {
            val metadataCallbacks = MetadataCallbacks()
            metadataCallbacks.quadDetectionCallback = QuadDetectionCallback {

                dispatcher.reportQuadDetection(it)
            }
            metadataCallbacks.firstSideRecognitionCallback = FirstSideRecognitionCallback {
                Log.i("MicroblinkScannerView", "first side scanned")
                dispatcher.reportFirstSideScanned()
            }

            return metadataCallbacks
        }

    private val scanResultListener: ScanResultListener
        get() {
            return object : ScanResultListener {
                override fun onScanningDone(recognitionSuccessType: RecognitionSuccessType) {
                    val recognizers =  mRecognizerBundle.recognizers.clone()
                    recognizers.forEach { recognizer ->
                        val resultState = recognizer.result.clone().resultState
                        Log.i("MicroblinkScannerView", "onScanningDone with result state: $resultState")
                        dispatcher.reportScanningDone(resultState)
                        if (resultState == Recognizer.Result.State.Valid) {
                            // result is valid, you can use it however you wish
                            mRecognizerRunnerView.pauseScanning()
                            dispatcher.reportFinishedScanning(recognizers)
                        }
                    }

                }

                override fun onUnrecoverableError(p0: Throwable) {
                    dispatcher.reportError(p0)
                    mRecognizerRunnerView.resetRecognitionState()
                }
            }
        }


    private fun setLicense(context: Context, licenseKey: String) {
        MicroblinkSDK.setShowTrialLicenseWarning(false)
        MicroblinkSDK.setLicenseKey(licenseKey, context)
        MicroblinkSDK.setIntentDataTransferMode(IntentDataTransferMode.PERSISTED_OPTIMISED)
    }

    override fun getView(): View {
        return parentView
    }


}

//private class MicroblinkEventDispatcher(binaryMessenger: BinaryMessenger, id: Int) {
//    private val methodChannel: MethodChannel
//    private val handler: Handler = Handler(Looper.getMainLooper())
//    var resumeScanningHandler: () -> Unit = {}
//
//    init {
//        methodChannel = MethodChannel(
//            binaryMessenger,
//            "com.microblink.blinkid.flutter/MicroblinkScannerWidget/$id"
//        )
//        methodChannel.setMethodCallHandler { call, result ->
//            when (call.method) {
//                "resumeScanning" -> {
//                    resumeScanningHandler()
//                    result.success(null)
//                }
//
//                else -> result.notImplemented()
//            }
//        }
//    }
//
//    fun reportQuadDetection(displayableQuadDetection: DisplayableQuadDetection) {
//        Log.i("com.microblink.blinkid.flutter.MicroblinkScannerView", "onQuadDetection: ${displayableQuadDetection.detectionStatus.name}")
//        val jsonObject = JSONObject()
//        jsonObject.put("detectionStatus", displayableQuadDetection.detectionStatus.name)
//
//        sendToMethodChannel("onDetectionStatusUpdate", jsonObject.toString())
//    }
//
//    fun reportFirstSideScanned() {
//        sendToMethodChannel("onFirstSideScanned", null)
//    }
//
//    fun sendToMethodChannel(method: String, arguments: Any?) {
//        handler.post {
//            Log.i("com.microblink.blinkid.flutter.MicroblinkScannerView", "dispatching to method channel: $method with arguments: $arguments")
//            methodChannel.invokeMethod(method, arguments)
//        }
//    }
//
//    fun reportScanningDone(resultState: Recognizer.Result.State) {
//        sendToMethodChannel(
//            "onScanDone", when (resultState) {
//                Recognizer.Result.State.Empty -> "empty"
//                Recognizer.Result.State.Uncertain -> "uncertain"
//                Recognizer.Result.State.Valid -> "valid"
//                Recognizer.Result.State.StageValid -> "stageValid"
//            }
//        )
//    }
//
//    fun reportFinishedScanning(result: String) {
//        sendToMethodChannel("onFinishScanning", result);
//    }
//
//    fun reportError(throwable: Throwable) {
//        sendToMethodChannel("onError", throwable.toString())
//    }
//}
