package com.cct.appfortv.flutter_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that wakes the screen and brings the app to front.
 *
 * ALWAYS posts a full-screen-intent notification — this is the ONLY method
 * that Android 11 reliably honors from background on all TV boxes.
 *
 * Also attempts direct startActivity() since it now works after
 * background_activity_starts_enabled=1 is set via ADB.
 */
class ForceOpenService : Service() {

    companion object {
        private const val TAG                 = "ForceOpenService"
        private const val SERVICE_CHANNEL_ID  = "force_open_service_ch"
        private const val ALERT_CHANNEL_ID    = "force_open_alert_ch"
        private const val NOTIF_SERVICE_ID    = 8001
        private const val NOTIF_ALERT_ID      = 8002
        private const val WAKE_LOCK_TAG       = "tvapp:force_open"

        fun launch(context: Context, disconnectType: String) {
            val intent = Intent(context, ForceOpenService::class.java).apply {
                putExtra("disconnect_type", disconnectType)
                putExtra("navigate_to", "code_view")
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "launch failed: ${e.message}")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val disconnectType = intent?.getStringExtra("disconnect_type") ?: "Disconnected"
        val navigateTo = intent?.getStringExtra("navigate_to") ?: "code_view"
        Log.d(TAG, "onStartCommand: disconnectType=$disconnectType navigateTo=$navigateTo")

        // Must call startForeground immediately (within 5s on Android 8+)
        startForeground(NOTIF_SERVICE_ID, buildServiceNotification())

        // Acquire wake lock — turns on the screen
        var wakeLock: PowerManager.WakeLock? = null
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            wakeLock = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK        or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                WAKE_LOCK_TAG
            )
            wakeLock.acquire(30_000L)
            Log.d(TAG, "WakeLock acquired")
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock failed: ${e.message}")
        }

        val launchIntent = Intent(applicationContext, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("navigate_to", navigateTo)
            putExtra("disconnect_type", disconnectType)
        }

        // ── ALWAYS post full-screen notification ──────────────────────────────
        // This is the ONLY method Android 11 reliably honors from background.
        // A full-screen intent with USE_FULL_SCREEN_INTENT permission will
        // auto-launch the activity when the device screen is off or on lockscreen.
        try {
            postFullScreenNotification(launchIntent)
            Log.d(TAG, "Full-screen notification: posted")
        } catch (e: Exception) {
            Log.e(TAG, "Full-screen notification failed: ${e.message}")
        }

        // ── Also try direct startActivity ─────────────────────────────────────
        // With background_activity_starts_enabled=1, this should now work too
        try {
            applicationContext.startActivity(launchIntent)
            Log.d(TAG, "Direct startActivity: SUCCESS")
        } catch (e: Exception) {
            Log.w(TAG, "Direct startActivity failed: ${e.message}")
        }

        // Don't release wake lock or stop immediately — give the activity
        // time to actually start and render
        android.os.Handler(mainLooper).postDelayed({
            try {
                wakeLock?.release()
            } catch (e: Exception) { /* already released */ }
            stopSelf(startId)
        }, 10_000L)

        return START_NOT_STICKY
    }

    private fun postFullScreenNotification(launchIntent: Intent) {
        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            NOTIF_ALERT_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val alertChannel = NotificationChannel(
                ALERT_CHANNEL_ID,
                "TV App Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(alertChannel)
        }

        val alertNotif = NotificationCompat.Builder(applicationContext, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("TV Display")
            .setContentText("Starting...")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .build()

        getSystemService(NotificationManager::class.java)
            ?.notify(NOTIF_ALERT_ID, alertNotif)
    }

    private fun buildServiceNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SERVICE_CHANNEL_ID,
                "TV App Service",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("TV App")
            .setContentText("Starting…")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .build()
    }
}
