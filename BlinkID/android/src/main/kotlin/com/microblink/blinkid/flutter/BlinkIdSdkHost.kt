package com.microblink.blinkid.flutter

import com.microblink.blinkid.core.BlinkIdSdk

interface BlinkIdSdkHost {
    val sdk: BlinkIdSdk?

    /** Incremented whenever the SDK is unloaded outside license recovery. */
    val sdkGeneration: Int

    /** The current SDK once any in-flight load or reload has finished. */
    suspend fun awaitSdk(): BlinkIdSdk?

    /** Refreshes the license lease when the last refresh is older than the refresh interval; null when not due. */
    suspend fun refreshLeaseIfDue(sdk: BlinkIdSdk): Result<Unit>?

    suspend fun refreshLease(sdk: BlinkIdSdk)

    /**
     * Closes the current SDK instance and initializes a new one from [sdkSettings].
     * Throws when the SDK was unloaded since [expectedGeneration] was read.
     */
    suspend fun reloadSdk(
        sdkSettings: Map<String, Any>?,
        expectedGeneration: Int,
    ): BlinkIdSdk
}
