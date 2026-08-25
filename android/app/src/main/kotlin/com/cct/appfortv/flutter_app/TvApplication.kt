package com.cct.appfortv.flutter_app

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log

/**
 * Custom Application class.
 *
 * Configures Amlogic hardware decoder properties to allow portrait/rotated
 * video playback and software decoder fallback on Android TV boxes.
 * Also registers a dynamic receiver for screen wake events (Standby exit).
 */
class TvApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        enableAmlogicDecoderFixes()
        registerScreenWakeReceiver()
    }

    private fun registerScreenWakeReceiver() {
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_USER_PRESENT)
                addAction("android.intent.action.DREAMING_STOPPED")
            }
            registerReceiver(object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    Log.d("TvApplication", "Screen wake detected: action=${intent.action}")
                    try {
                        val pkg = context.packageName
                        Runtime.getRuntime().exec(
                            arrayOf("am", "start",
                                "-n", "$pkg/$pkg.MainActivity",
                                "-a", "android.intent.action.MAIN",
                                "-c", "android.intent.category.LAUNCHER",
                                "-f", "0x10200000")
                        )
                    } catch (e: Exception) {
                        Log.w("TvApplication", "Screen wake launch failed: ${e.message}")
                    }
                }
            }, filter)
            Log.d("TvApplication", "ScreenWakeReceiver registered successfully")
        } catch (e: Exception) {
            Log.e("TvApplication", "Failed to register ScreenWakeReceiver: ${e.message}")
        }
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
