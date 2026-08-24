package com.cct.appfortv.flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Fired by AlarmManager 8 seconds after boot.
 * Launches the app via ForceOpenService — by this time the system
 * has fully settled and won't kill the process.
 */
class LaunchAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "LaunchAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Alarm fired — launching app")
        try {
            val serviceIntent = Intent(context, ForceOpenService::class.java).apply {
                putExtra("navigate_to", "session")
                putExtra("disconnect_type", "boot")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "ForceOpenService started from alarm")
        } catch (e: Exception) {
            Log.e(TAG, "Alarm launch failed: ${e.message}")
            // Last resort — direct activity start
            try {
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                    putExtra("launched_on_boot", true)
                }
                context.startActivity(launchIntent)
            } catch (e2: Exception) {
                Log.e(TAG, "Direct start also failed: ${e2.message}")
            }
        }
    }
}
