package com.microblink.blinkid.flutter

import android.content.Context
import android.util.Log
import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.microblink.blinkid.MicroblinkSDK
import com.microblink.blinkid.directApi.RecognizerRunner
import com.microblink.blinkid.entities.recognizers.Recognizer
import com.microblink.blinkid.entities.recognizers.RecognizerBundle
import com.microblink.blinkid.flutter.recognizers.RecognizerSerializers
import com.microblink.blinkid.hardware.orientation.Orientation
import com.microblink.blinkid.image.Image
import com.microblink.blinkid.image.ImageBuilder
import com.microblink.blinkid.intent.IntentDataTransferMode
import com.microblink.blinkid.metadata.MetadataCallbacks
import com.microblink.blinkid.metadata.detection.quad.DisplayableQuadDetection
import com.microblink.blinkid.metadata.detection.quad.QuadDetectionCallback
import com.microblink.blinkid.metadata.recognition.FirstSideRecognitionCallback
import com.microblink.blinkid.recognition.RecognitionSuccessType
import com.microblink.blinkid.view.recognition.ScanResultListener
import org.json.JSONObject

class MicroblinkScanner internal constructor(
    context: Context,
    creationParams: MicroblinkCreationParams,
    callbacks: Callbacks
) : ImageAnalysis.Analyzer {
    private val recognizerRunner: RecognizerRunner
    private val recognizerBundle: RecognizerBundle
    private val callbacks: Callbacks
    private var isPaused = false

    init {
        com.microblink.blinkid.util.Log.setLogLevel(com.microblink.blinkid.util.Log.LogLevel.LOG_VERBOSE);
        setLicense(context, creationParams.licenseKey)
        this.callbacks = callbacks
        recognizerBundle = createRecognizerBundle(creationParams.recognizerCollection)
        recognizerRunner = createRecognizer(context, recognizerBundle)
        recognizerRunner.setMetadataCallbacks(createMetadataCallbacks(callbacks))
        com.microblink.blinkid.util.Log.setLogLevel(com.microblink.blinkid.util.Log.LogLevel.LOG_VERBOSE);
    }

    @OptIn(ExperimentalGetImage::class)
    override fun analyze(imageProxy: ImageProxy) {
        Log.i(
            "MicroblinkScanner",
            "Analyze called. Recognizer state: ${recognizerRunner.currentState}, isPaused: $isPaused"
        )
        if (!isPaused && recognizerRunner.currentState == RecognizerRunner.State.READY) {
            imageProxy.image?.let {
                Log.i("MicroblinkScanner", "Sent image to analyze.")
                val image = ImageBuilder.buildImageFromCamera2Image(it, Orientation.ORIENTATION_LANDSCAPE_RIGHT, null)
                recognizerRunner.recognizeVideoImage(image, createScanResultListener(image, imageProxy))
            }
        } else {
            imageProxy.close()
        }
    }

    private fun createScanResultListener(image: Image, imageProxy: ImageProxy): ScanResultListener {
        return object : ScanResultListener {
            override fun onScanningDone(recognitionSuccessType: RecognitionSuccessType) {
                image.dispose()
                imageProxy.close()
                Log.i("MicroblinkScanner", "Scaning is done: $recognitionSuccessType")
                if (recognitionSuccessType == RecognitionSuccessType.UNSUCCESSFUL || isPaused) {
                    return
                }

                val recognizers = recognizerBundle.recognizers
                recognizers.forEach { recognizer ->
                    val resultState = recognizer.result.resultState
                    callbacks.onScanningDone(resultState)
                    if (resultState == Recognizer.Result.State.Valid) {
                        isPaused = true
                        callbacks.onScanned(recognizers.clone())
                        return
                    }
                }
            }

            override fun onUnrecoverableError(throwable: Throwable) {
                Log.i("MicroblinkScanner", "Scanner erroed out: $throwable")
                image.dispose()
                imageProxy.close()
                callbacks.onError(throwable)
                recognizerRunner.resetRecognitionState()
            }
        }
    }

    fun resume() {
        recognizerRunner.resetRecognitionState()
        isPaused = false
    }

    private fun setLicense(context: Context, licenseKey: String?) {
        MicroblinkSDK.setShowTrialLicenseWarning(false)
        MicroblinkSDK.setLicenseKey(licenseKey!!, context)
        MicroblinkSDK.setIntentDataTransferMode(IntentDataTransferMode.OPTIMISED)
    }

    private fun createRecognizerBundle(recognizerCollection: Map<String?, Any?>): RecognizerBundle {
        val jsonRecognizerCollection = JSONObject(recognizerCollection)
        return RecognizerSerializers.INSTANCE.deserializeRecognizerCollection(jsonRecognizerCollection)
    }

    private fun createRecognizer(context: Context, recognizerBundle: RecognizerBundle): RecognizerRunner {
        val recognizerRunner = RecognizerRunner.getSingletonInstance()
        recognizerRunner.initialize(context, recognizerBundle) { throwable -> callbacks.onError(throwable) }
        return recognizerRunner
    }

    private fun createMetadataCallbacks(callbacks: Callbacks): MetadataCallbacks {
        val metadataCallbacks = MetadataCallbacks()
        metadataCallbacks.quadDetectionCallback = QuadDetectionCallback { displayableQuadDetection ->
            callbacks.onDetectionStatusUpdated(displayableQuadDetection)
        }
        metadataCallbacks.firstSideRecognitionCallback = FirstSideRecognitionCallback { callbacks.onFirstSideScanned() }
        return metadataCallbacks
    }

    fun dispose() {
        recognizerRunner.terminate()
    }

    internal interface Callbacks {
        fun onFirstSideScanned()
        fun onDetectionStatusUpdated(displayableQuadDetection: DisplayableQuadDetection)
        fun onScanningDone(state: Recognizer.Result.State)
        fun onScanned(recognizers: Array<Recognizer<Recognizer.Result>>)
        fun onError(throwable: Throwable)
    }
}