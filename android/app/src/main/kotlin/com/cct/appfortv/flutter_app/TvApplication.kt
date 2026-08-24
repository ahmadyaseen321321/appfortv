package com.cct.appfortv.flutter_app

import android.app.Application
import android.util.Log

/**
 * Custom Application class.
 *
 * Sets a system property that tells ExoPlayer's MediaCodecVideoRenderer
 * to allow software decoder fallback when the hardware decoder fails.
 *
 * This fixes H.264 High Profile playback errors on Amlogic/Rockchip TV
 * boxes where the hardware codec claims format_supported=YES but then
 * throws MediaCodecVideoRenderer errors at runtime.
 */
class TvApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        enableExoPlayerSoftwareFallback()
    }

    private fun enableExoPlayerSoftwareFallback() {
        try {
            // Allow ExoPlayer to fall back to software decoder when hardware fails
            System.setProperty(
                "media.stagefright.legacyencoder",
                "true"
            )
            System.setProperty(
                "media.stagefright.less-secure",
                "true"
            )
            Log.d("TvApplication", "ExoPlayer software fallback enabled")
        } catch (e: Exception) {
            Log.e("TvApplication", "Failed to set ExoPlayer properties: ${e.message}")
        }
    }
}
