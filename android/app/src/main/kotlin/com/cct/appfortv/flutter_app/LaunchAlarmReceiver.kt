package com.cct.appfortv.flutter_app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log

/**
 * Fired by AlarmManager after boot (alarms at 5s, 15s, 30s).
 *
 * Uses `am start` as the primary launch strategy since it bypasses
 * background activity start restrictions on Android 10+.
 */
class LaunchAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "LaunchAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Alarm fired — launching app")

        // Wake the screen
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "tvapp:alarm_wake"
            )
            wl.acquire(10_000L)
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock failed: ${e.message}")
        }

        // Strategy 1: `am start` via shell (most reliable on TV boxes)
        try {
            val pkg = context.packageName
            val process = Runtime.getRuntime().exec(
                arrayOf("am", "start",
                    "-n", "$pkg/$pkg.MainActivity",
                    "-a", "android.intent.action.MAIN",
                    "-c", "android.intent.category.LAUNCHER",
                    "-f", "0x10200000",
                    "--es", "navigate_to", "session",
                    "--es", "disconnect_type", "boot",
                    "--ez", "launched_on_boot", "true")
            )
            val exitCode = process.waitFor()
            Log.d(TAG, "am start: exitCode=$exitCode")
            if (exitCode == 0) return  // Success, skip other strategies
        } catch (e: Exception) {
            Log.w(TAG, "am start failed: ${e.message}")
        }

        // Strategy 2: PendingIntent.send()
        try {
            val launchIntent = buildLaunchIntent(context)
            val pi = PendingIntent.getActivity(
                context, 901, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            pi.send()
            Log.d(TAG, "PendingIntent.send: SUCCESS")
        } catch (e: Exception) {
            Log.w(TAG, "PendingIntent.send failed: ${e.message}")
        }

        // Strategy 3: Direct startActivity
        try {
            context.startActivity(buildLaunchIntent(context))
            Log.d(TAG, "startActivity: SUCCESS")
        } catch (e: Exception) {
            Log.w(TAG, "startActivity failed: ${e.message}")
        }

        // Strategy 4: ForceOpenService
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
            Log.d(TAG, "ForceOpenService started")
        } catch (e: Exception) {
            Log.e(TAG, "ForceOpenService failed: ${e.message}")
        }
    }

    private fun buildLaunchIntent(context: Context): Intent {
        return (context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("navigate_to", "session")
            putExtra("disconnect_type", "boot")
            putExtra("launched_on_boot", true)
        }
    }
}
