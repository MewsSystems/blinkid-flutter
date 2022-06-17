package com.microblink.flutter


interface MicroblinkCreationParamsFactory {
    fun fromMap(args: Map<*, *>): MicroblinkCreationParams
}

interface OverlaySettingsFactory {
    fun fromMap(args: Map<*, *>): OverlaySettings
}


public class MicroblinkCreationParams(
    val overlaySettings: OverlaySettings,
    val licenseKey: String,
    val recognizerCollection: Map<String, *>
) {
    companion object : MicroblinkCreationParamsFactory {
        override fun fromMap(args: Map<*, *>): MicroblinkCreationParams {
            @Suppress("UNCHECKED_CAST")
            return MicroblinkCreationParams(
                overlaySettings = OverlaySettings.fromMap(args["overlaySettings"] as Map<*, *>),
                licenseKey = args["licenseKey"] as String,
                recognizerCollection = args["recognizerCollection"] as Map<String, *>
            )

        }
    }
}

public class OverlaySettings(val useFrontCamera: Boolean = false, val flipFrontCamera: Boolean = false) {
    companion object : OverlaySettingsFactory {
        override fun fromMap(args: Map<*, *>): OverlaySettings {
            return OverlaySettings(
                useFrontCamera = (args["useFrontCamera"] as Boolean?) ?: false,
                flipFrontCamera = (args["flipFrontCamera"] as Boolean?) ?: false
            )
        }
    }
}