package com.cct.appfortv.flutter_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

/**
 * Receives BOOT_COMPLETED and uses two strategies to auto-start the app:
 *
 * 1. Immediate: startForegroundService via ForceOpenService (fast path)
 * 2. AlarmManager backup: schedules a 5-second alarm that fires
 *    LaunchAlarmReceiver — this survives the process killer and guarantees
 *    the app opens even if the immediate launch gets killed.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val intentAction = intent.action ?: return
        Log.d(TAG, "onReceive: action=$intentAction")

        val isBoot = intentAction == Intent.ACTION_BOOT_COMPLETED ||
                     intentAction == "android.intent.action.QUICKBOOT_POWERON" ||
                     intentAction == "com.htc.intent.action.QUICKBOOT_POWERON" ||
                     intentAction == "android.intent.action.LOCKED_BOOT_COMPLETED" ||
                     intentAction == "android.intent.action.MY_PACKAGE_REPLACED"

        if (!isBoot) return

        Log.d(TAG, "Boot detected — scheduling launch")

        // Strategy 1: immediate foreground service launch
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
            Log.d(TAG, "Strategy 1: ForceOpenService started")
        } catch (e: Exception) {
            Log.e(TAG, "Strategy 1 failed: ${e.message}")
        }

        // Strategy 2: AlarmManager backup — fires 8 seconds after boot
        // This runs even if Strategy 1's process gets killed by the system
        try {
            val alarmIntent = Intent(context, LaunchAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = SystemClock.elapsedRealtime() + 8_000L
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAt,
                pendingIntent
            )
            Log.d(TAG, "Strategy 2: AlarmManager set for 8s")
        } catch (e: Exception) {
            Log.e(TAG, "Strategy 2 failed: ${e.message}")
        }
    }
}
