package com.microblink.blinkid.flutter

import com.microblink.blinkid.core.BlinkIdSdk

interface BlinkIdSdkHost {
    /**
     * Runs [block] after every earlier SDK lifecycle operation (load, unload, reload, license
     * recovery) has finished and before any later one starts. The members below must only be used
     * from inside an exclusive block.
     */
    suspend fun <T> runExclusive(block: suspend () -> T): T

    val sdk: BlinkIdSdk?

    /** Refreshes the license lease when the last refresh is older than the refresh interval; null when not due. */
    suspend fun refreshLeaseIfDue(sdk: BlinkIdSdk): Result<Unit>?

    suspend fun refreshLease(sdk: BlinkIdSdk)

    /** Closes the current SDK instance and initializes a new one from [sdkSettings]. */
    suspend fun reloadSdk(sdkSettings: Map<String, Any>?): BlinkIdSdk
}
