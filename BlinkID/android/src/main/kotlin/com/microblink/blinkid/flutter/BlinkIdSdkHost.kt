package com.microblink.blinkid.flutter

import com.microblink.blinkid.core.BlinkIdSdk

interface BlinkIdSdkHost {
    val sdk: BlinkIdSdk?

    /** The current SDK once any in-flight load or reload has finished. */
    suspend fun awaitSdk(): BlinkIdSdk?

    /** Refreshes the license lease when the last refresh is older than the refresh interval; null when not due. */
    suspend fun refreshLeaseIfDue(sdk: BlinkIdSdk): Result<Unit>?

    suspend fun refreshLease(sdk: BlinkIdSdk)

    /** Closes the current SDK instance and initializes a new one from [sdkSettings]. */
    suspend fun reloadSdk(sdkSettings: Map<String, Any>?): BlinkIdSdk
}
