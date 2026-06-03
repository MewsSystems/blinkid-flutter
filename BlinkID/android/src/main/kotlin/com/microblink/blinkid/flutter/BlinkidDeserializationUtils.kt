package com.microblink.blinkid.flutter

import android.graphics.BitmapFactory
import android.os.Parcelable
import com.microblink.blinkid.core.BlinkIdSdkSettings
import com.microblink.blinkid.core.result.FieldType
import com.microblink.blinkid.core.result.classinfo.Country
import com.microblink.blinkid.core.result.classinfo.DocumentClassInfo
import com.microblink.blinkid.core.result.classinfo.Region
import com.microblink.blinkid.core.result.classinfo.Type
import com.microblink.blinkid.core.session.BlinkIdSessionSettings
import com.microblink.blinkid.core.session.ScanningMode
import com.microblink.blinkid.core.settings.DocumentFilter
import com.microblink.blinkid.core.settings.DocumentNumberRedactionSettings
import com.microblink.blinkid.core.settings.RedactionSettings
import com.microblink.blinkid.core.settings.RedactionSettingsResolver
import com.microblink.blinkid.core.settings.ScanningSettings
import com.microblink.blinkid.core.settings.SensitivityLevel
import com.microblink.blinkid.core.settings.scanning.BarcodeModuleSettings
import com.microblink.blinkid.core.settings.scanning.DocumentCaptureModuleSettings
import com.microblink.blinkid.core.settings.scanning.MrzModuleSettings
import com.microblink.blinkid.core.settings.scanning.VizModuleSettings
import com.microblink.blinkid.ux.settings.BlinkIdUxSettings
import com.microblink.blinkid.ux.settings.ClassFilter
import com.microblink.core.network.RequestTimeout
import com.microblink.core.session.InputImageSource
import com.microblink.core.settings.RedactionMode
import com.microblink.core.utils.defaultResourceDownloadUrl
import com.microblink.core.utils.defaultResourcesLocalFolder
import kotlin.time.Duration.Companion.milliseconds
import kotlinx.parcelize.Parcelize
import kotlinx.parcelize.RawValue
import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import com.microblink.ux.camera.CameraLensFacing
import com.microblink.ux.camera.CameraSettings

object BlinkIdDeserializationUtils {

    private const val TAG = "BlinkIdFlutter"

    fun deserializeBlinkIdSdkSettings(blinkIdSdkSettingsMap: Map<String, Any>?): BlinkIdSdkSettings? {
        val licenseKey = blinkIdSdkSettingsMap?.get("licenseKey") as? String ?: return null

        val sdkSettings = BlinkIdSdkSettings(
            licenseKey = licenseKey,
            licensee = blinkIdSdkSettingsMap["licensee"] as? String,
            downloadResources = blinkIdSdkSettingsMap["downloadResources"] as? Boolean ?: true,
            resourceDownloadUrl = blinkIdSdkSettingsMap["resourceDownloadUrl"] as? String
                ?: defaultResourceDownloadUrl,
            resourceLocalFolder = blinkIdSdkSettingsMap["resourceLocalFolder"] as? String
                ?: defaultResourcesLocalFolder,
            resourceRequestTimeout = deserializeResourceRequestTimeout(blinkIdSdkSettingsMap["resourceRequestTimeout"] as? Map<String, Any>),
            microblinkProxyUrl = blinkIdSdkSettingsMap["microblinkProxyURL"] as? String,
            )

        return sdkSettings
    }

    fun deserializeBlinkIdSessionSettings(
        blinkIdSdkSessionSettingsMap: Map<String, Any>?,
        isDirectApi: Boolean
    ): BlinkIdSessionSettings {
        if (blinkIdSdkSessionSettingsMap == null) return BlinkIdSessionSettings()

        val scanningSettingsMap =
            blinkIdSdkSessionSettingsMap["scanningSettings"] as? Map<String, Any>
        val scanningSettings = deserializeScanningSettings(scanningSettingsMap)
        logSessionSettings(
            source = if (isDirectApi) "directApi" else "performScan",
            sessionMap = blinkIdSdkSessionSettingsMap,
            scanningSettingsMap = scanningSettingsMap,
            scanningSettings = scanningSettings,
        )

        return BlinkIdSessionSettings(
            inputImageSource = if (isDirectApi) InputImageSource.Photo else InputImageSource.Video,
            scanningMode = deserializeScanningMode(blinkIdSdkSessionSettingsMap["scanningMode"] as? String),
            scanningSettings = scanningSettings,
        )
    }

    private fun deserializeScanningMode(value: String?): ScanningMode {
        return when (value?.lowercase()) {
            "single" -> ScanningMode.Single
            "automatic" -> ScanningMode.Automatic
            else -> ScanningMode.Automatic
        }
    }

    private fun deserializeScanningSettings(scanningSettingsMap: Map<String, Any>?): ScanningSettings {
        if (scanningSettingsMap == null) return ScanningSettings()
        return ScanningSettings(
            documentCaptureModule = optionalDocumentCaptureModuleSettings(
                scanningSettingsMap["documentCaptureModule"],
            ),
            barcodeModule = optionalBarcodeModuleSettings(scanningSettingsMap["barcodeModule"]),
            mrzModule = optionalMrzModuleSettings(scanningSettingsMap["mrzModule"]),
            vizModule = optionalVizModuleSettings(scanningSettingsMap["vizModule"]),
            maxAllowedMismatchesPerField = (scanningSettingsMap["maxAllowedMismatchesPerField"] as? Int)?.toUInt()
                ?: 0u,
        )
    }

    private fun optionalDocumentCaptureModuleSettings(value: Any?): DocumentCaptureModuleSettings? {
        val map = value as? Map<String, Any> ?: return null
        return deserializeDocumentCaptureModuleSettings(map)
    }

    private fun optionalBarcodeModuleSettings(value: Any?): BarcodeModuleSettings? {
        val map = value as? Map<String, Any> ?: return null
        return deserializeBarcodeModuleSettings(map)
    }

    private fun optionalMrzModuleSettings(value: Any?): MrzModuleSettings? {
        val map = value as? Map<String, Any> ?: return null
        return deserializeMrzModuleSettings(map)
    }

    private fun optionalVizModuleSettings(value: Any?): VizModuleSettings? {
        val map = value as? Map<String, Any> ?: return null
        return deserializeVizModuleSettings(map)
    }

    private fun deserializeDocumentCaptureModuleSettings(map: Map<String, Any>): DocumentCaptureModuleSettings {
        return DocumentCaptureModuleSettings(
            inputImageCropped = map["inputImageCropped"] as? Boolean ?: false,
            unsupportedDocumentsAllowed = map["unsupportedDocumentsAllowed"] as? Boolean ?: false,
            secondSideWithNoExtractableDataSkipped = map["secondSideWithNoExtractableDataSkipped"] as? Boolean ?: true,
            passportDataPageScanOnly = map["passportDataPageScanOnly"] as? Boolean ?: true,
            faceImageExtractionEnabled = map["faceImageExtractionEnabled"] as? Boolean ?: false,
            faceImagePresenceMandatory = map["faceImagePresenceMandatory"] as? Boolean ?: false,
            inputImageReturnEnabled = map["inputImageReturnEnabled"] as? Boolean ?: false,
            documentImageReturnEnabled = map["documentImageReturnEnabled"] as? Boolean ?: false,
            inputImageMargin = (map["inputImageMargin"] as? Number)?.toFloat(),
            dotsPerInch = map["dotsPerInch"] as? Int ?: 250,
            extensionFactor = (map["extensionFactor"] as? Number)?.toFloat() ?: 0.0f,
            blurSensitivityLevel = deserializeSensitivityLevel(map["blurSensitivityLevel"] as? String),
            imageWithBlurRejected = map["imageWithBlurRejected"] as? Boolean ?: true,
            glareSensitivityLevel = deserializeSensitivityLevel(map["glareSensitivityLevel"] as? String),
            imageWithGlareRejected = map["imageWithGlareRejected"] as? Boolean ?: true,
            tiltSensitivityLevel = deserializeSensitivityLevel(map["tiltSensitivityLevel"] as? String),
            imageWithPoorLightingRejected = map["imageWithPoorLightingRejected"] as? Boolean ?: true,
            imageWithHandOcclusionRejected = map["imageWithHandOcclusionRejected"] as? Boolean ?: true,
        )
    }

    private fun deserializeSensitivityLevel(value: String?): SensitivityLevel {
        return when (value?.lowercase()) {
            "off" -> SensitivityLevel.Off
            "low" -> SensitivityLevel.Low
            "mid" -> SensitivityLevel.Mid
            "high" -> SensitivityLevel.High
            else -> SensitivityLevel.Mid
        }
    }

    private fun deserializeBarcodeModuleSettings(map: Map<String, Any>): BarcodeModuleSettings {
        return BarcodeModuleSettings(
            presenceMandatory = map["presenceMandatory"] as? Boolean ?: false,
            barcodeImageReturnEnabled = map["barcodeImageReturnEnabled"] as? Boolean ?: false,
            pdf417ScanningEnabled = map["pdf417ScanningEnabled"] as? Boolean ?: true,
            qrScanningEnabled = map["qrScanningEnabled"] as? Boolean ?: true,
            upceScanningEnabled = map["upceScanningEnabled"] as? Boolean ?: false,
            upcaScanningEnabled = map["upcaScanningEnabled"] as? Boolean ?: false,
            code128ScanningEnabled = map["code128ScanningEnabled"] as? Boolean ?: false,
            code39ScanningEnabled = map["code39ScanningEnabled"] as? Boolean ?: false,
            ean8ScanningEnabled = map["ean8ScanningEnabled"] as? Boolean ?: false,
            ean13ScanningEnabled = map["ean13ScanningEnabled"] as? Boolean ?: false,
            itfScanningEnabled = map["itfScanningEnabled"] as? Boolean ?: false,
            dataMatrixScanningEnabled = map["dataMatrixScanningEnabled"] as? Boolean ?: false,
        )
    }

    private fun deserializeMrzModuleSettings(map: Map<String, Any>): MrzModuleSettings {
        return MrzModuleSettings(
            presenceMandatory = map["presenceMandatory"] as? Boolean ?: false,
        )
    }

    private fun deserializeVizModuleSettings(map: Map<String, Any>): VizModuleSettings {
        return VizModuleSettings(
            presenceMandatory = map["presenceMandatory"] as? Boolean ?: false,
            signatureImageExtractionEnabled = map["signatureImageExtractionEnabled"] as? Boolean ?: false,
            characterValidationEnabled = map["characterValidationEnabled"] as? Boolean ?: true,
            resultAggregationEnabled = map["resultAggregationEnabled"] as? Boolean ?: true,
        )
    }

    private fun deserializeResourceRequestTimeout(resourceRequestTimeoutMap: Map<String, Any>?): RequestTimeout {
        if (resourceRequestTimeoutMap == null) return RequestTimeout.DEFAULT
        return RequestTimeout(
            connectionTimeout = (resourceRequestTimeoutMap["connectionTimeoutMilliseconds"] as? Int ?: 10000).milliseconds,
            writeTimeout = (resourceRequestTimeoutMap["writeTimeoutMilliseconds"] as? Int ?: 10000).milliseconds,
            readTimeout = (resourceRequestTimeoutMap["readTimeoutMilliseconds"] as? Int ?: 10000).milliseconds
        )
    }

    private fun deserializeDocumentFilter(documentFilterMap: Map<String, Any>?): DocumentFilter {
        return if (documentFilterMap != null) {
            val filter = DocumentFilter()

            (documentFilterMap["country"] as? String)?.let {
                filter.country = enumValueOf<Country>(it.replaceFirstChar { char -> char.uppercase() })
            }
            (documentFilterMap["region"] as? String)?.let {
                filter.region = enumValueOf<Region>(it.replaceFirstChar { char -> char.uppercase() })
            }
            (documentFilterMap["documentType"] as? String)?.let {
                filter.type = enumValueOf<Type>(it.replaceFirstChar { char -> char.uppercase() })
            }
            filter
        } else {
            DocumentFilter()
        }
    }

    private fun deserializeRedactionMode(value: String?): RedactionMode {
        return when (value?.lowercase()) {
            "none" -> RedactionMode.None
            "imageonly" -> RedactionMode.ImageOnly
            "resultfieldsonly" -> RedactionMode.ResultFieldsOnly
            "fullresult" -> RedactionMode.FullResult
            else -> RedactionMode.FullResult
        }
    }

    fun deserializeRedactionSettings(redactionSettingsMap: Map<String, Any>?): RedactionSettings? {
        if (redactionSettingsMap == null) return null
        val mode = deserializeRedactionMode(redactionSettingsMap["mode"] as? String)
        val fields = (redactionSettingsMap["fields"] as? List<String>)?.map {
            enumValueOf<FieldType>(it.replaceFirstChar { char -> char.uppercase() })
        } ?: emptyList()
        val docNumSettings = deserializeDocumentNumberRedactionSettings(
            redactionSettingsMap["documentNumberRedactionSettings"] as? Map<String, Any>
        )
        val redactMrz = redactionSettingsMap["redactMrzResult"] as? Boolean ?: false
        val redactBarcode = redactionSettingsMap["redactBarcodeResult"] as? Boolean ?: false
        return RedactionSettings(
            mode,
            fields,
            docNumSettings ?: DocumentNumberRedactionSettings(),
            redactMrz,
            redactBarcode,
        )
    }

    private fun deserializeDocumentNumberRedactionSettings(documentNumberRedactionSettingsMap: Map<String, Any>?): DocumentNumberRedactionSettings? {
        if (documentNumberRedactionSettingsMap == null) return null
        return DocumentNumberRedactionSettings(
            prefixDigitsVisible = (documentNumberRedactionSettingsMap["prefixDigitsVisible"] as? Int)?.toUByte() ?: 0u,
            suffixDigitsVisible = (documentNumberRedactionSettingsMap["suffixDigitsVisible"] as? Int)?.toUByte() ?: 0u,
        )
    }

    fun deserializeRedactionSettingsResolver(
        redactionSettingsResolverMap: Map<String, Any>?
    ): RedactionSettingsResolver? {
        if (redactionSettingsResolverMap == null) return null
        val documentRedactionList = redactionSettingsResolverMap["documentRedactionList"] as? List<Map<String, Any>> ?: return null
        return CustomRedactionSettingsResolver(documentRedactionList)
    }

    fun deserializeBlinkIdUxSettings(
        blinkidUxSettingsMap: Map<String, Any>?,
        classFilterMap: Map<String, Any>?,
        redactionSettingsResolverMap: Map<String, Any>? = null
    ): BlinkIdUxSettings {
        if (blinkidUxSettingsMap == null) return BlinkIdUxSettings()
        return BlinkIdUxSettings(
            stepTimeoutDuration = (blinkidUxSettingsMap["stepTimeoutDuration"] as? Int
                ?: 15000).milliseconds,
            stateBasedTimeoutDuration = (blinkidUxSettingsMap["inactivityTimeoutDuration"] as? Int
                ?: 10000).milliseconds,
            allowHapticFeedback = (blinkidUxSettingsMap["allowHapticFeedback"] as? Boolean) ?: true,
            classFilter = CustomClassFilter(classFilterMap),
            redactionSettingsResolver = deserializeRedactionSettingsResolver(redactionSettingsResolverMap),
        )
    }

    fun deserializeCameraSettings(blinkIdScanningUxSettingsMap: Map<String, Any>?): CameraSettings {
        if (blinkIdScanningUxSettingsMap == null) return CameraSettings()
        return CameraSettings(
            lensFacing = deserializeCameraLens(blinkIdScanningUxSettingsMap["preferredCamera"] as? String)
        )
    }
    fun deserializeCameraLens(value: String?): CameraLensFacing {
        return when (value?.lowercase()) {
            "front" -> CameraLensFacing.LensFacingFront
            "back" -> CameraLensFacing.LensFacingBack
            else -> CameraLensFacing.LensFacingBack
        }
    }
    fun deserializeClassFilter(
        classFilterMap: Map<String, Any>?,
        classInfo: DocumentClassInfo
    ): Boolean {
        if (classFilterMap == null) return true

        var includeClass = false
        var excludeClass = true

        val includedClasses = classFilterMap["includeDocuments"] as? List<Map<String, Any>>
        if (includedClasses != null) {
            for (includedClass in includedClasses) {
                includeClass = includeClass || matchClassFilter(includedClass, classInfo)
            }
        } else {
            includeClass = true
        }

        val excludedClasses = classFilterMap["excludeDocuments"] as? List<Map<String, Any>>
        if (excludedClasses != null) {
            for (excludedClass in excludedClasses) {
                excludeClass = excludeClass && !matchClassFilter(excludedClass, classInfo)
            }
        }

        return includeClass && excludeClass
    }

    private fun matchClassFilter(
        filteredClass: Map<String, Any>,
        classInfo: DocumentClassInfo
    ): Boolean {
        val country = filteredClass["country"] as? String
        val region = filteredClass["region"] as? String
        val documentType = filteredClass["documentType"] as? String

        return (country == null || enumValueOf<Country>(country.replaceFirstChar { char -> char.uppercase() }) == classInfo.country) &&
                (region == null || enumValueOf<Region>(region.replaceFirstChar { char -> char.uppercase() }) == classInfo.region) &&
                (documentType == null || enumValueOf<Type>(documentType.replaceFirstChar { char -> char.uppercase() }) == classInfo.type)
    }

    fun base64ToBitmap(base64Str: String?): Bitmap? {
        return try {
            val decodedBytes = Base64.decode(base64Str, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.size)
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    private fun logSessionSettings(
        source: String,
        sessionMap: Map<String, Any>,
        scanningSettingsMap: Map<String, Any>?,
        scanningSettings: ScanningSettings,
    ) {
        Log.i(TAG, "[$source] scanningMode=${sessionMap["scanningMode"]}")
        Log.i(
            TAG,
            "[$source] raw modules: documentCapture=${scanningSettingsMap?.get("documentCaptureModule")}, " +
                "barcode=${scanningSettingsMap?.get("barcodeModule")}, " +
                "mrz=${scanningSettingsMap?.get("mrzModule")}, " +
                "viz=${scanningSettingsMap?.get("vizModule")}",
        )
        Log.i(
            TAG,
            "[$source] deserialized modules: documentCapture=${scanningSettings.documentCaptureModule}, " +
                "barcode=${scanningSettings.barcodeModule}, " +
                "mrz=${scanningSettings.mrzModule}, " +
                "viz=${scanningSettings.vizModule}",
        )
        scanningSettings.barcodeModule?.let {
            Log.i(TAG, "[$source] barcode.presenceMandatory=${it.presenceMandatory}")
        }
        scanningSettings.mrzModule?.let {
            Log.i(TAG, "[$source] mrz.presenceMandatory=${it.presenceMandatory}")
        }
        scanningSettings.vizModule?.let {
            Log.i(TAG, "[$source] viz.presenceMandatory=${it.presenceMandatory}")
        }
    }
}

@Parcelize
private class CustomClassFilter(
    private val classFilterMap: @RawValue Map<String, Any>?
) : ClassFilter, Parcelable {

    override fun classAllowed(documentClass: DocumentClassInfo): Boolean {
        return BlinkIdDeserializationUtils.deserializeClassFilter(classFilterMap, documentClass)
    }
}

@Parcelize
private class CustomRedactionSettingsResolver(
    private val documentRedactionList: @RawValue List<Map<String, Any>>
) : RedactionSettingsResolver, Parcelable {

    override fun resolveRedactionSettings(classInfo: DocumentClassInfo): RedactionSettings? {
        for (redactionDict in documentRedactionList) {
            if (shouldUseRedactionSettings(redactionDict, classInfo)) {
                return BlinkIdDeserializationUtils.deserializeRedactionSettings(redactionDict)
            }
        }
        return null
    }

    private fun shouldUseRedactionSettings(
        redactionDict: Map<String, Any>,
        classInfo: DocumentClassInfo
    ): Boolean {
        val documentFilters = redactionDict["documentFilter"] as? List<Map<String, Any>> ?: return true
        if (documentFilters.isEmpty()) return true
        return documentFilters.any { filterDict ->
            BlinkIdDeserializationUtils.deserializeClassFilter(
                mapOf(
                    "includeDocuments" to listOf(filterDict)
                ),
                classInfo
            )
        }
    }
}

