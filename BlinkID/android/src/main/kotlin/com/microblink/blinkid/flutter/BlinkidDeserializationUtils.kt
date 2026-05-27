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
import com.microblink.blinkid.core.settings.ScanningSettings
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
import com.microblink.ux.camera.CameraLensFacing
import com.microblink.ux.camera.CameraSettings

object BlinkIdDeserializationUtils {

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

        return BlinkIdSessionSettings(
            inputImageSource = if (isDirectApi) InputImageSource.Photo else InputImageSource.Video,
            scanningMode = ScanningMode.entries[blinkIdSdkSessionSettingsMap["scanningMode"] as? Int
                ?: ScanningMode.Automatic.ordinal],
            scanningSettings = deserializeScanningSettings(blinkIdSdkSessionSettingsMap["scanningSettings"] as? Map<String, Any>),
        )
    }

    private fun deserializeScanningSettings(scanningSettingsMap: Map<String, Any>?): ScanningSettings {
        if (scanningSettingsMap == null) return ScanningSettings()
        return ScanningSettings(
            documentCaptureModule = deserializeDocumentCaptureModuleSettings(scanningSettingsMap["documentCaptureModule"] as? Map<String, Any>),
            barcodeModule = deserializeBarcodeModuleSettings(scanningSettingsMap["barcodeModule"] as? Map<String, Any>),
            mrzModule = deserializeMrzModuleSettings(scanningSettingsMap["mrzModule"] as? Map<String, Any>),
            vizModule = deserializeVizModuleSettings(scanningSettingsMap["vizModule"] as? Map<String, Any>),
            maxAllowedMismatchesPerField = (scanningSettingsMap["maxAllowedMismatchesPerField"] as? Int)?.toUInt()
                ?: 0u,
        )
    }

    private fun deserializeDocumentCaptureModuleSettings(map: Map<String, Any>?): DocumentCaptureModuleSettings {
        if (map == null) return DocumentCaptureModuleSettings()
        return DocumentCaptureModuleSettings(
            documentImageReturnEnabled = map["documentImageReturnEnabled"] as? Boolean ?: false,
            faceImageExtractionEnabled = map["faceImageExtractionEnabled"] as? Boolean ?: false,
            inputImageReturnEnabled = map["returnInputImages"] as? Boolean ?: false,
            inputImageCropped = map["inputImageCropped"] as? Boolean ?: false,
        )
    }

    private fun deserializeBarcodeModuleSettings(map: Map<String, Any>?): BarcodeModuleSettings {
        if (map == null) return BarcodeModuleSettings()
        return BarcodeModuleSettings(
            presenceMandatory = map["presenceMandatory"] as? Boolean ?: false,
            pdf417ScanningEnabled = map["pdf417ScanningEnabled"] as? Boolean ?: true,
            qrScanningEnabled = map["qrScanningEnabled"] as? Boolean ?: true,
        )
    }

    private fun deserializeMrzModuleSettings(map: Map<String, Any>?): MrzModuleSettings {
        if (map == null) return MrzModuleSettings()
        return MrzModuleSettings(
            presenceMandatory = map["presenceMandatory"] as? Boolean ?: false,
        )
    }

    private fun deserializeVizModuleSettings(map: Map<String, Any>?): VizModuleSettings {
        if (map == null) return VizModuleSettings()
        return VizModuleSettings(
            presenceMandatory = map["presenceMandatory"] as? Boolean ?: false,
        )
    }

    private fun deserializeResourceRequestTimeout(resourceRequestTimeoutMap: Map<String, Any>?): RequestTimeout {
        if (resourceRequestTimeoutMap == null) return RequestTimeout.DEFAULT
        return RequestTimeout(
            connectionTimeoutMillis = resourceRequestTimeoutMap["connectionTimeoutMilliseconds"] as? Int ?: 10000,
            writeTimeoutMillis = resourceRequestTimeoutMap["writeTimeoutMilliseconds"] as? Int ?: 10000,
            readTimeoutMillis = resourceRequestTimeoutMap["readTimeoutMilliseconds"] as? Int ?: 10000
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

    fun deserializeRedactionSettings(redactionSettingsMap: Map<String, Any>?): RedactionSettings? {
        if (redactionSettingsMap == null) return null
        val mode = RedactionMode.entries[redactionSettingsMap["mode"] as? Int ?: RedactionMode.FullResult.ordinal]
        val fields = (redactionSettingsMap["fields"] as? List<String>)?.map {
            enumValueOf<FieldType>(it.replaceFirstChar { char -> char.uppercase() })
        } ?: emptyList()
        val docNumSettings = deserializeDocumentNumberRedactionSettings(
            redactionSettingsMap["documentNumberRedactionSettings"] as? Map<String, Any>
        )
        return RedactionSettings(
            mode,
            fields,
            docNumSettings ?: DocumentNumberRedactionSettings(),
        )
    }

    private fun deserializeDocumentNumberRedactionSettings(documentNumberRedactionSettingsMap: Map<String, Any>?): DocumentNumberRedactionSettings? {
        if (documentNumberRedactionSettingsMap == null) return null
        return DocumentNumberRedactionSettings(
            prefixDigitsVisible = (documentNumberRedactionSettingsMap["prefixDigitsVisible"] as? Int)?.toUByte() ?: 0u,
            suffixDigitsVisible = (documentNumberRedactionSettingsMap["suffixDigitsVisible"] as? Int)?.toUByte() ?: 0u,
        )
    }


    fun deserializeBlinkIdUxSettings(
        blinkidUxSettingsMap: Map<String, Any>?,
        classFilterMap: Map<String, Any>?
    ): BlinkIdUxSettings {
        if (blinkidUxSettingsMap == null) return BlinkIdUxSettings()
        return BlinkIdUxSettings(
            stepTimeoutDuration = (blinkidUxSettingsMap["stepTimeoutDuration"] as? Int
                ?: 15000).milliseconds,
            allowHapticFeedback = (blinkidUxSettingsMap["allowHapticFeedback"] as? Boolean)?: true,
            classFilter = CustomClassFilter(classFilterMap),

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
}

@Parcelize
private class CustomClassFilter(
    private val classFilterMap: @RawValue Map<String, Any>?
) : ClassFilter, Parcelable {

    override fun classAllowed(documentClass: DocumentClassInfo): Boolean {
        return BlinkIdDeserializationUtils.deserializeClassFilter(classFilterMap, documentClass)
    }
}
