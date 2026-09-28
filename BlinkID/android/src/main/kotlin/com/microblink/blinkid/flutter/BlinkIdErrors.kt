package com.microblink.blinkid.flutter

import com.microblink.blinkid.core.InvalidLicenseKeyException
import com.microblink.blinkid.core.LicenseLockedException
import com.microblink.blinkid.core.RemoteLicenseCheckException
import com.microblink.blinkid.core.SdkInitError
import com.microblink.blinkid.core.SdkInitializationException

internal const val BLINKID_LICENSE_ERROR_CODE = "blinkid_license_error"

internal fun Throwable?.isBlinkIdLicenseError(): Boolean =
    when (this) {
        null -> false
        is LicenseLockedException, is InvalidLicenseKeyException, is RemoteLicenseCheckException -> true
        is SdkInitializationException -> reason is SdkInitError.LicenseError
        else -> message.isLicenseMessage() || cause.isBlinkIdLicenseError()
    }

private fun String?.isLicenseMessage(): Boolean =
    this != null && (contains("license", ignoreCase = true) || contains("licence", ignoreCase = true))
