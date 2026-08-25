package com.cct.appfortv.flutter_app

import android.app.Application
import android.util.Log

/**
 * Custom Application class.
 *
 * Configures Amlogic hardware decoder properties to allow portrait/rotated
 * video playback and software decoder fallback on Android TV boxes.
 */
class TvApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        enableAmlogicDecoderFixes()
    }

    private fun enableAmlogicDecoderFixes() {
        try {
            // Enable video layer rotation on Amlogic hardware decoders.
            // Fixes buffer allocation failures (-1010 / 0xfffffc0e) when playing
            // portrait or non-standard aspect ratio videos on Amlogic TV chips.
            System.setProperty("vendor.media.omx.videolayerrotation.enable", "true")
            System.setProperty("media.amlogic.omx.videolayerrotation.enable", "true")

            // Enable ExoPlayer software decoder fallback properties
            System.setProperty("media.stagefright.legacyencoder", "true")
            System.setProperty("media.stagefright.less-secure", "true")

            // Execute setprop via shell to update Android system properties directly
            Runtime.getRuntime().exec(arrayOf("setprop", "vendor.media.omx.videolayerrotation.enable", "true"))
            Runtime.getRuntime().exec(arrayOf("setprop", "vendor.media.omx.display_mode", "3"))

            Log.d("TvApplication", "Amlogic decoder fixes and video rotation enabled successfully")
        } catch (e: Exception) {
            Log.e("TvApplication", "Failed to set decoder properties: ${e.message}")
        }
    }
}
